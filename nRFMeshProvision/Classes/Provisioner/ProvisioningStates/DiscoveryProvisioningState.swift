//
//  DiscoveryProvisioningState.swift
//  nRFMeshProvision
//
//  Created by Mostafa Berg on 20/12/2017.
//

import Foundation
import CoreBluetooth

class DiscoveryProvisioningState: NSObject, ProvisioningStateProtocol {
    
    // MARK: - Properties
    private var provisioningService: CBService!
    private var dataInCharacteristic: CBCharacteristic!
    private var dataOutCharacteristic: CBCharacteristic!
    
    private var deviceInfomationService: CBService!
    private var deviceInfomationCharacteristic: CBCharacteristic!
    
    // MARK: - ProvisioningStateProtocol
    var target: UnprovisionedMeshNodeProtocol
    
    func humanReadableName() -> String {
        return "PB-GATT Discovery"
    }
    
    required init(withTargetNode aNode: UnprovisionedMeshNodeProtocol) {
        target = aNode
        super.init()
        target.basePeripheral().delegate = self
    }
    
    func execute() {
        target.basePeripheral().discoverServices([MeshServiceProvisioningUUID,DeviceInfomationServiceUUID])
    }
    
    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            services.forEach({ (aService) in
                if aService.uuid == MeshServiceProvisioningUUID {
                    print("Discovered mesh provisioning service")
                    provisioningService = aService
                    //Discover Data in & Data out characteristics
                    print("Discovering characteristics for provisioning service")
                    peripheral.discoverCharacteristics([MeshCharacteristicProvisionDataOutUUID, MeshCharacteristicProvisionDataInUUID], for: aService)
                } else if aService.uuid == DeviceInfomationServiceUUID {
                    print("Discovered mesh deviceinmation service")
                    deviceInfomationService = aService
                    print("Discovering characteristics for provisioning service")
                    peripheral.discoverCharacteristics([DeviceInfomationCharacteristicUUID], for: aService)
                }
            })
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            characteristics.forEach({ (aCharacteristic) in
                if aCharacteristic.uuid == MeshCharacteristicProvisionDataInUUID {
                    print("Discovered data in charcateristic")
                    dataInCharacteristic = aCharacteristic
                } else if aCharacteristic.uuid == MeshCharacteristicProvisionDataOutUUID {
                    print("Discovered data out characteristic")
                    dataOutCharacteristic  = aCharacteristic
                    peripheral.setNotifyValue(true, for: dataOutCharacteristic)
                } else if aCharacteristic.uuid == DeviceInfomationCharacteristicUUID {
                    print("DeviceInfomation data out characteristic")
                    deviceInfomationCharacteristic = aCharacteristic
                    
                    peripheral.readValue(for: deviceInfomationCharacteristic)
                }
                
                if dataInCharacteristic != nil && dataOutCharacteristic != nil && dataOutCharacteristic.isNotifying {
                    print("Discovery completed")
                    target.completedDiscovery(withProvisioningService: provisioningService,
                                              dataInCharacteristic: dataInCharacteristic,
                                              andDataOutCharacteristic: dataOutCharacteristic)
                }
            })
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //NOOP
        if characteristic.uuid == DeviceInfomationCharacteristicUUID {
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == dataOutCharacteristic {
            if dataInCharacteristic != nil {
                target.completedDiscovery(withProvisioningService: provisioningService,
                                          dataInCharacteristic: dataInCharacteristic,
                                          andDataOutCharacteristic: dataOutCharacteristic)
            }
        }
    }

}

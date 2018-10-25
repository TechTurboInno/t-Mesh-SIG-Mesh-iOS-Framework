//
//  InviteProvisioningState.swift
//  nRFMeshProvision
//
//  Created by Mostafa Berg on 20/12/2017.
//

import Foundation
import CoreBluetooth

class InviteProvisioningState: NSObject, ProvisioningStateProtocol {

    // MARK: - Properties
    private var provisioningService: CBService!
    private var dataInCharacteristic: CBCharacteristic!
    private var dataOutCharacteristic: CBCharacteristic!

    private var duration: UInt8
    // MARK: - ProvisioningStateProtocol
    var target: UnprovisionedMeshNodeProtocol

    func humanReadableName() -> String {
        return "Invite"
    }

    required init(withTargetNode aNode: UnprovisionedMeshNodeProtocol) {
        target                              = aNode
        duration                            = 0x05 //Default attention timer is 5 seconds
        super.init()
        target.basePeripheral().delegate    = self
        //If services and characteristics are already discovered, set them now
        let discovery                       = target.discoveredServicesAndCharacteristics()
        provisioningService                 = discovery.provisionService
        dataInCharacteristic                = discovery.dataInCharacteristic
        dataOutCharacteristic               = discovery.dataOutCharacteristic
    }
    
    public func setDuration(_ aDuration: UInt8) {
        duration = aDuration
    }

    func execute() {
        let invitePDU = Data(bytes: [0x03, 0x00, duration])
        print(invitePDU.hexString())

        // Store generated invite PDU Data, first two bytes are PDU related and are not used further.
        target.generatedProvisioningInviteData(invitePDU.dropFirst().dropFirst())
        target.basePeripheral().writeValue(invitePDU, for: dataInCharacteristic, type: .withoutResponse)
    }
   
    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        //NOOP
    }
   
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        //NOOP
    }
   
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            let provisioningMessage = data[0]
            let messageType         = data[1]
            
            if provisioningMessage == 0x02 && messageType == 0x8A {
                target.updateDeviceInfomation(data);
            }
            
            guard provisioningMessage == 0x03 && messageType == 0x01 else {
                print("Unexpected message type received")
                print("Expected: 0301")
                print("Received: \(provisioningMessage)\(messageType)")
                return
            }
            print("Received capabilities provisioning message")
            let elementCount            = Int(data[2])
            let algorithm               = ProvisioningAlgorithm(rawValue: UInt16(data[3] << 0xFF) + UInt16(data[4] & 0x00FF))!
            let pubKeyType              = PublicKeyInformationAvailability(rawValue: data[5])!
            let staticOOBType           = StaticOutOfBoundInformationAvailability(rawValue: data[6])!
            let outputOOBSize           = data[7]
            let supportedOutputActions  = OutputOutOfBoundActions.calculateOutputActionsFromBitMask(aBitMask: UInt16(data[8] << 0xFF) + UInt16(data[9] & 0x00FF))
            let supportedInputActions   = InputOutOfBoundActions.calculateInputActionsFromBitmask(aBitMask: UInt16(data[11] << 0xFF) + UInt16(data[12] & 0x00FF))
            let inputOOBSize            = data[10]
            print("Element count: \(elementCount),Algorithm: \(algorithm), PublicKeyAvailable: \(pubKeyType), StaticOOBAvailable: \(staticOOBType), OutputOOBSize: \(outputOOBSize), InputOOBSize: \(inputOOBSize)")
            if supportedOutputActions.count == 0 {
                print("No output actions supported")
            } else {
                for anAction in supportedOutputActions {
                    print("Supported Output Action: \(anAction.description())")
                }
            }
            if supportedInputActions.count == 0 {
                print("No input actions supported")
            } else {
                for anAction in supportedInputActions {
                    print("Supported Input Action: \(anAction.description())")
                }
            }
            target.receivedCapabilitiesData(data.dropFirst().dropFirst())
            let capabilities = InviteCapabilities(withElementCount: elementCount,
                                                  algorithm: algorithm,
                                                  publicKeyAvailability: pubKeyType,
                                                  staticOOBAvailability: staticOOBType,
                                                  outputOOBSize: outputOOBSize,
                                                  inputOOBSize: inputOOBSize,
                                                  supportedInputOOB: supportedInputActions,
                                                  supportedOutputOOB: supportedOutputActions)
            target.parsedCapabilities(capabilities)
        }
   }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        //NOOP
        print("Notifications: \(characteristic.isNotifying)")
    }
}

//
//  GenericOnOffSetControllerState.swift
//  nRFMeshProvision
//
//  Created by Mostafa Berg on 28/05/2018.
//

import Foundation
import CoreBluetooth

class GenericGroupSetState: NSObject, GenericModelControllerStateProtocol {
    
    // MARK: - Properties
    private var proxyService            : CBService!
    private var dataInCharacteristic    : CBCharacteristic!
    private var dataOutCharacteristic   : CBCharacteristic!
    private var networkLayer            : NetworkLayer!
    private var segmentedData           : Data
    private var targetState             : Data?
    
    // MARK: - ConfiguratorStateProtocol
    var destinationAddress  : Data
    var target              : ProvisionedMeshNodeProtocol
    var stateManager        : MeshStateManager
    
    required init(withTargetProxyNode aNode: ProvisionedMeshNodeProtocol,
                  destinationAddress aDestinationAddress: Data,
                  andStateManager aStateManager: MeshStateManager) {
        target = aNode
        segmentedData = Data()
        stateManager = aStateManager
        destinationAddress = aDestinationAddress
        super.init()
        target.basePeripheral().delegate = self
        //If services and characteristics are already discovered, set them now
        let discovery           = target.discoveredServicesAndCharacteristics()
        proxyService            = discovery.proxyService
        dataInCharacteristic    = discovery.dataInCharacteristic
        dataOutCharacteristic   = discovery.dataOutCharacteristic
        
        networkLayer = NetworkLayer(withStateManager: stateManager, andSegmentAcknowlegdement: { (ackData) -> (Void) in
            self.acknowlegeSegment(withAckData: ackData)
        })
    }
    
    func humanReadableName() -> String {
        return "Generic OnOff Set"
    }
    
    public func setTargetState(aTargetState: Data) {
        targetState = aTargetState
    }
    
    func execute() {
        var message: GenericGroupSetMessage
        if let targetState = targetState {
            message = GenericGroupSetMessage(withTargetState: targetState)
        } else {
            print("No target state set, nothing to execute")
            return
        }
        //Send to destination
        let payloads = message.assemblePayload(withMeshState: stateManager.state(), toAddress: destinationAddress)
        for aPayload in payloads! {
            var data = Data([0x00]) //Type => Network
            data.append(aPayload)
            print("Full PDU: \(data.hexString())")
            if data.count <= target.basePeripheral().maximumWriteValueLength(for: .withoutResponse) {
                print("Sending  data: \(data.hexString())")
                target.basePeripheral().writeValue(data, for: dataInCharacteristic, type: .withoutResponse)
            } else {
                print("maximum write length is shorter than PDU, will Segment")
                var segmentedProvisioningData = [Data]()
                data = Data(data.dropFirst()) //Drop old network header, SAR will now set that instead.
                let chunkRanges = self.calculateDataRanges(data, withSize: 19)
                for aRange in chunkRanges {
                    var header = Data()
                    let chunkIndex = chunkRanges.index(of: aRange)!
                    if chunkIndex == 0 {
                        header.append(Data([0x40])) //SAR start
                    } else if chunkIndex == chunkRanges.count - 1 {
                        header.append(Data([0xC0])) //SAR end
                    } else {
                        header.append(Data([0x80])) //SAR cont.
                    }
                    var chunkData = Data(header)
                    chunkData.append(Data(data[aRange]))
                    segmentedProvisioningData.append(Data(chunkData))
                }
                for aSegment in segmentedProvisioningData {
                    print("Sending segment: \(aSegment.hexString())")
                    target.basePeripheral().writeValue(aSegment, for: dataInCharacteristic, type: .withoutResponse)
                }
            }
        }
    }
    
    func receivedData(incomingData : Data) {
    }
    
    private func calculateDataRanges(_ someData: Data, withSize aChunkSize: Int) -> [Range<Int>] {
        var totalLength = someData.count
        var ranges = [Range<Int>]()
        var partIdx = 0
        while (totalLength > 0) {
            var range : Range<Int>
            if totalLength > aChunkSize {
                totalLength -= aChunkSize
                range = (partIdx * aChunkSize) ..< aChunkSize + (partIdx * aChunkSize)
            } else {
                range = (partIdx * aChunkSize) ..< totalLength + (partIdx * aChunkSize)
                totalLength = 0
            }
            ranges.append(range)
            partIdx += 1
        }
        return ranges
    }
    
    private func acknowlegeSegment(withAckData someData: Data) {
        print("Sending acknowledgement: \(someData.hexString())")
    }
    
    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        //NOOP
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        //NOOP
    }
    
    var lastMessageType = 0xC0
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Cahrcateristic value updated: \(characteristic.value!.hexString())")
        //SAR handling
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("Characteristic notification state changed")
    }
}



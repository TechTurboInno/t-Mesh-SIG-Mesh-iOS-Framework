//
//  GenericCustomDataGetMessage.swift
//  nRFMeshProvision
//
//  Created by 朱彬 on 2018/9/26.
//

import Foundation

public struct GenericCustomDataGetMessage {
    var opcode  : Data
    var payload : Data
    
    public init() {
        opcode = Data([0xC1, 0x11, 0x02])
        payload = Data([0xC4, 0x00])
    }
    
    public func assemblePayload(withMeshState aState: MeshState, toAddress aDestinationAddress: Data) -> [Data]? {
        let appKey = aState.appKeys[0].values.first!
        let accessMessage = AccessMessagePDU(withPayload: payload, opcode: opcode, appKey: appKey, netKey: aState.netKey, seq: SequenceNumber(), ivIndex: aState.IVIndex, source: aState.unicastAddress, andDst: aDestinationAddress)
        let networkPDU = accessMessage.assembleNetworkPDU()
        return networkPDU
    }
}

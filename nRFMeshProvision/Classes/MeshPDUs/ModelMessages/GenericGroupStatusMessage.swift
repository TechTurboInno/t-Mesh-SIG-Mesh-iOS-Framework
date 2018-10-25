//
//  GenericCustomDataStatus.swift
//  nRFMeshProvision
//
//  Created by 朱彬 on 2018/9/27.
//

import Foundation

public struct GenericGroupStatusMessage {
    public var sourceAddress: Data
    public var dataStatus: Data
    
    public init(withPayload aPayload: Data, andSoruceAddress srcAddress: Data) {
        sourceAddress = srcAddress
        dataStatus = aPayload
    }
}

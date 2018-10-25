//
//  ModelConfigurationTableViewController.swift
//  nRFMeshProvision_Example
//
//  Created by Mostafa Berg on 16/04/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import nRFMeshProvision
import CoreBluetooth

private enum SubscriptionActions {
    case subscriptionAdd
    case subscriptionDelete
}
private enum ModelAppActions {
    case modelAppBind
    case modelAppUnbind
}

class ModelConfigurationTableViewController: UITableViewController, ProvisionedMeshNodeDelegate, UITextFieldDelegate, ToggleCellDelegate, PublicationSettingsDelegate, UIGestureRecognizerDelegate {

    // MARK: - Outlets & Actions
    @IBOutlet weak var vendorLabel: UILabel!
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBAction func editButtonTapped(_ sender: Any) {
        tableView.isEditing = !tableView.isEditing
        if tableView.isEditing {
            editButton.title = "Done"
        } else {
            editButton.title = "Edit"
        }
    }
    
    // MARK: - Properties
    private var nodeEntry: MeshNodeEntry!
    private var meshstateManager: MeshStateManager!
    private var selectedModelIndexPath: IndexPath!
    private var companyName: String?
    private var companyIdentifier: Data?
    private var targetNode: ProvisionedMeshNode!
    private var originalDelegate: ProvisionedMeshNodeDelegate?
    private var centralManager: CBCentralManager?
    private var lastSubscriptionAction: SubscriptionActions?
    private var lastModelAppAction: ModelAppActions?

    private var msilder1 : UISlider!
    private var msilder2 : UISlider!
    private var mtextField : UITextField!
    private var mtextField1 : UITextField!
    
    // MARK: - Implementation
    public func setProxyNode(_ aNode: ProvisionedMeshNode) {
        centralManager = (UIApplication.shared.delegate as? AppDelegate)?.meshManager.centralManager()
        targetNode = aNode
        originalDelegate = targetNode.delegate
        targetNode.delegate = self
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        //Node control cell is not selectable
        return indexPath.section != 3
    }

    public func didSelectSubscriptionAddressAdd(_ anAddress: Data) {
        let elementIdx = selectedModelIndexPath.section
        let modelIdx = selectedModelIndexPath.row
        let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])

        lastSubscriptionAction = .subscriptionAdd
        targetNode.nodeSubscriptionAddressAdd(anAddress,
                                              onElementAddress: elementAddress,
                                              modelIdentifier: aModel,
                                              onDestinationAddress: nodeEntry.nodeUnicast!)
    }
    
    public func didSelectSubscriptionAddressDelete(_ anAddress: Data) {
        let elementIdx = selectedModelIndexPath.section
        let modelIdx = selectedModelIndexPath.row
        let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        
        lastSubscriptionAction = .subscriptionDelete
        targetNode.nodeSubscriptionAddressDelete(anAddress,
                                              onElementAddress: elementAddress,
                                              modelIdentifier: aModel,
                                              onDestinationAddress: nodeEntry.nodeUnicast!)
    }

    func didSelectUnbindAppKeyAtIndex(_ anAppKeyIndex: UInt16) {
        lastModelAppAction = .modelAppUnbind
        var anIndex = anAppKeyIndex.bigEndian
        let appKeyIndexData = Data(bytes: &anIndex, count: MemoryLayout<UInt16>.size)
        var keyFound = false
        for aBoundAppKeyIndex in nodeEntry.appKeys {
            if aBoundAppKeyIndex == appKeyIndexData {
                keyFound = true
            }
        }
        let appKey = meshstateManager.state().appKeys[Int(anAppKeyIndex)]
        let selectedAppKeyName = appKey.keys.first!
        if !keyFound {
            showstatusCodeAlert(withTitle: "AppKey is not on the node's list",
                                andMessage: "\"\(selectedAppKeyName)\" has not been added to this node's AppKey list and unbinding cannot be performed on this model.")
        } else {
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let unicast = nodeEntry.nodeUnicast!
            let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
            targetNode.unbindAppKey(withIndex: appKeyIndexData,
                                  modelId: aModel,
                                  elementAddress: elementAddress,
                                  onDestinationAddress: nodeEntry.nodeUnicast!)
            print("Unbinding appkey \(selectedAppKeyName) on Model \(aModel.hexString())")
        }
    }

    func didSelectAppKeyAtIndex(_ anAppKeyIndex: UInt16) {
        lastModelAppAction = .modelAppBind
        var anIndex = anAppKeyIndex.bigEndian
        let appKeyIndexData = Data(bytes: &anIndex, count: MemoryLayout<UInt16>.size)
        var keyFound = false
        for aBoundAppKeyIndex in nodeEntry.appKeys {
            if aBoundAppKeyIndex == appKeyIndexData {
                keyFound = true
            }
        }
        let appKey = meshstateManager.state().appKeys[Int(anAppKeyIndex)]
        let selectedAppKeyName = appKey.keys.first!
        if !keyFound {
            showstatusCodeAlert(withTitle: "AppKey is not available",
                            andMessage: "\"\(selectedAppKeyName)\" has not been added to this node's AppKey list and cannot be bound to this model.")
        } else {
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let unicast = nodeEntry.nodeUnicast!
            let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
            targetNode.bindAppKey(withIndex: appKeyIndexData,
                                  modelId: aModel,
                                  elementAddress: elementAddress,
                                  onDestinationAddress: nodeEntry.nodeUnicast!)
            print("Binding appkey \(selectedAppKeyName) to Model \(aModel.hexString())")
            
            
//            for i in 161...180{
//                let a = i
//                let elementAddress = Data([unicast[0], unicast[1] + UInt8(a)])
//                print(elementAddress.hexString())
//                targetNode.bindAppKey(withIndex: appKeyIndexData,
//                                      modelId: aModel,
//                                      elementAddress: elementAddress,
//                                      onDestinationAddress: elementAddress)
//                print("Binding appkey \(selectedAppKeyName) to Model \(aModel.hexString())")
//
//                sleep(1)
//            }
        }
    }

    public func handleAlertForStatusCode(_ aStatusCode: MessageStatusCodes) {
        switch aStatusCode {
        case .invalidPublishParameters:
            showstatusCodeAlert(withTitle: "Invalid Publish Parameters", andMessage: "The node has reported the publish parameters are invalid")
        case .cannotBind:
            showstatusCodeAlert(withTitle: "Cannot Bind", andMessage: "This model cannot be bound to an AppKey")
        case .featureNotSupported:
            showstatusCodeAlert(withTitle: "Not supported", andMessage: "This feature not supported")
        case .invalidAdderss:
            showstatusCodeAlert(withTitle: "Invalid Address", andMessage: "Node reported invalid address.")
        case .invalidAppKeyIndex:
            showstatusCodeAlert(withTitle: "Invalid AppKey Index", andMessage: "Node reported this AppKey index as invalid")
        case .invalidBinding:
            showstatusCodeAlert(withTitle: "Invalid binding", andMessage: "Node reported this Binding as invalid")
        case .invalidModel:
            showstatusCodeAlert(withTitle: "Invalid model", andMessage: "Node reported this model as invalid")
        case .invalidNetKeyIndex:
            showstatusCodeAlert(withTitle: "Invalid NetKey Index", andMessage: "Node reported NetKey as invalid")
        case .unspecifiedError:
            showstatusCodeAlert(withTitle: "Unspecified Error", andMessage: "Node has reported an unspecified error")
        case .insufficientResources:
            showstatusCodeAlert(withTitle: "Insufficient resources", andMessage: "Node has reported insufficient resources")
        case .cannotRemove:
            showstatusCodeAlert(withTitle: "Cannot remove", andMessage: "Node has reported it cannot remove this item")
        case .cannotSet:
            showstatusCodeAlert(withTitle: "Cannot set", andMessage: "Node has reported it cannot set this item")
        case .cannotUpdate:
            showstatusCodeAlert(withTitle: "Cannot update", andMessage: "Node has reported it cannot update this item")
        case .notASubscribedModel:
            showstatusCodeAlert(withTitle: "Cannot subscribe", andMessage: "Node has reported this is not a subscribe model")
        case .keyIndexAlreadyStored:
            showstatusCodeAlert(withTitle: "Already stored", andMessage: "Node has reported this key index is already stored")
        case .storageFailure:
            showstatusCodeAlert(withTitle: "Storage failure", andMessage: "Node has reported a storage failure")
        case .temporarilyUnableToChangeState:
            showstatusCodeAlert(withTitle: "State failure", andMessage: "Node has reported that the state cannot be changed temporarily")
        case .success:
            break
        }
    }

    public func showstatusCodeAlert(withTitle aTitle: String, andMessage aMessage: String) {
        let alert = UIAlertController(title: aTitle,
                          message: aMessage,
                          preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { (_) in
            self.dismiss(animated: true)
        }
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    public func setMeshStateManager(_ aManager: MeshStateManager) {
        meshstateManager = aManager
    }

    public func setNodeEntry(_ aNode: MeshNodeEntry, withModelPath anIndexPath: IndexPath) {
        nodeEntry = aNode
        selectedModelIndexPath = anIndexPath
        let elementIdx = selectedModelIndexPath.section
        let modelIdx = selectedModelIndexPath.row
        let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
        if aModel.count == 2 {
            let upperInt = UInt16(aModel[0]) << 8
            let lowerInt = UInt16(aModel[1])
            if let modelIdentifier = MeshModelIdentifiers(rawValue: upperInt | lowerInt) {
                let modelString = MeshModelIdentifierStringConverter().stringValueForIdentifier(modelIdentifier)
                title = modelString
            } else {
                title = aModel.hexString()
            }
        } else {
            let vendorCompanyData = Data(aModel[0...1])
            let vendorModelId     = Data(aModel[2...3])
            var vendorModelInt    =  UInt32(0)
            vendorModelInt |= UInt32(aModel[0]) << 24
            vendorModelInt |= UInt32(aModel[1]) << 16
            vendorModelInt |= UInt32(aModel[2]) << 8
            vendorModelInt |= UInt32(aModel[3])

            companyIdentifier = vendorCompanyData
            companyName = CompanyIdentifiers().humanReadableNameFromIdentifier(vendorCompanyData)

            if let vendorModelIdentifier = MeshVendorModelIdentifiers(rawValue: vendorModelInt) {
                let vendorModelString = MeshVendorModelIdentifierStringConverter().stringValueForIdentifier(vendorModelIdentifier)
                title = vendorModelString
            } else {
                let formattedModel = "\(vendorCompanyData.hexString()):\(vendorModelId.hexString())"
                title = formattedModel
            }
        }
    }
    
    // MARK: - ToggleCell delegate
    func didToggleCell(aCell: ToggleControlTableViewCell, didSetOnStateTo newOnState: Bool) {
        let targetstate: Data = newOnState ? Data([0x01]) : Data([0x00])
        let elementIdx = selectedModelIndexPath.section
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])

        if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
            let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
            if let addresses = element.subscriptionAddressesForModelId(targetModel) {
                if addresses.count > 0 {
                    for anAddress in addresses {
                        targetNode.nodeGenericOnOffSet(elementAddress, onDestinationAddress: anAddress, withtargetState: targetstate)
                    }
                    return
                }
            }
        }
        
        targetNode.nodeGenericOnOffSet(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!, withtargetState: targetstate)
    }

    // MARK: - ProvisionedMeshNodeDelegate
    func receivedGenericOnOffStatusMessage(_ status: GenericOnOffStatusMessage) {
        print("OnOff status = \(status.onOffStatus.hexString())")
    }

    func receivedGenericCustomDataStatusMessage(_ status: GenericCustomDataStatusMessage){
        print("OnOff status = \(status.dataStatus.hexString())")
        let a = Int(status.dataStatus[1])
        let b = Int(status.dataStatus[2])
        let lowerInt = Int(status.dataStatus[3])
        let upperInt = Int(status.dataStatus[4]) << 8
        
        let v =  lowerInt + upperInt
    
        let s = String(format:"High:%d\r\nLow:%d\r\nDelaytime:%d", arguments:[a, b, v])
        
        let alertVC = UIAlertController(title: "", message: s, preferredStyle: UIAlertControllerStyle.alert)
        let acSure = UIAlertAction(title: "OK", style: UIAlertActionStyle.destructive) { (UIAlertAction) -> Void in
            print("click Sure")
        }
        
        alertVC.addAction(acSure)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    func nodeDidCompleteDiscovery(_ aNode: ProvisionedMeshNode) {
        //noop
    }

    func nodeShouldDisconnect(_ aNode: ProvisionedMeshNode) {
        if centralManager != nil {
            centralManager!.cancelPeripheralConnection(aNode.blePeripheral())
        }
    }

    func receivedNodeResetStatus(_ resetStatusData: NodeResetStatusMessage) {
        //noop
    }

    func receivedCompositionData(_ compositionData: CompositionStatusMessage) {
        //noop
    }

    func receivedAppKeyStatusData(_ appKeyStatusData: AppKeyStatusMessage) {
        //noop
    }

    func receivedModelAppStatus(_ modelAppStatusData: ModelAppStatusMessage) {
        if modelAppStatusData.statusCode == .success {
            if lastModelAppAction == .modelAppBind {
                print("AppKey Bound!")
            } else if lastModelAppAction == .modelAppUnbind {
                print("AppKey Unbound!")
            } else {
                print("Other ModelApp action performed")
            }
            print("AppKeyIndex: \(modelAppStatusData.appkeyIndex.hexString())")
            print("Element Addr: \(modelAppStatusData.elementAddress.hexString())")
            print("ModelIdentifier: \(modelAppStatusData.modelIdentifier.hexString())")
            print("Source addr: \(modelAppStatusData.sourceAddress.hexString())")
            print("Status code: \(modelAppStatusData.statusCode)")
            
            // Update state with configured key
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let state = meshstateManager.state()
            if let anIndex = state.provisionedNodes.index(where: { $0.nodeUnicast == nodeEntry.nodeUnicast}) {
                let aNodeEntry = state.provisionedNodes[anIndex]
                if var anElement = aNodeEntry.elements?[elementIdx] {
                    if lastModelAppAction == .modelAppBind {
                        anElement.setKeyBinding(modelAppStatusData.appkeyIndex, forModelId: aModel)
                        aNodeEntry.elements?.remove(at: elementIdx)
                        aNodeEntry.elements?.insert(anElement, at: elementIdx)
                    } else if lastModelAppAction == .modelAppUnbind {
                        anElement.removeKeyBinding(modelAppStatusData.appkeyIndex, forModelId: aModel)
                        aNodeEntry.elements?.remove(at: elementIdx)
                        aNodeEntry.elements?.insert(anElement, at: elementIdx)
                    }
                }
                //and update
                state.provisionedNodes.remove(at: anIndex)
                state.provisionedNodes.insert(aNodeEntry, at: anIndex)
                meshstateManager.saveState()
                meshstateManager.restoreState()
                let targetNodeToUpdate = nodeEntry.nodeUnicast!
                nodeEntry = meshstateManager.state().provisionedNodes.first { (aNode) -> Bool in
                    return aNode.nodeUnicast == targetNodeToUpdate
                }
            }
            tableView.reloadData()
        } else {
            handleAlertForStatusCode(modelAppStatusData.statusCode)
            print("Failed. Status code: \(modelAppStatusData.statusCode)")
        }
        lastModelAppAction = nil
    }

    func receivedModelPublicationStatus(_ modelPublicationStatusData: ModelPublicationStatusMessage) {
        if modelPublicationStatusData.statusCode == .success {
            if modelPublicationStatusData.publishAddress == Data([0x00, 0x00]) {
                print("Publication address cleared!")
            } else {
                print("Publication address set!")
            }
            print("Publication address: \(modelPublicationStatusData.publishAddress.hexString())")
            print("AppKeyIndex: \(modelPublicationStatusData.appKeyIndex.hexString())")
            print("Element Addr: \(modelPublicationStatusData.elementAddress.hexString())")
            print("ModelIdentifier: \(modelPublicationStatusData.modelIdentifier.hexString())")
            print("Source addr: \(modelPublicationStatusData.sourceAddress.hexString())")
            print("Status code: \(modelPublicationStatusData.statusCode)")
            
            // Update state with configured Publication address
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let state = meshstateManager.state()
            
            if let anIndex = state.provisionedNodes.index(where: { $0.nodeUnicast == nodeEntry.nodeUnicast}) {
                let aNodeEntry = state.provisionedNodes[anIndex]
                if var anElement = aNodeEntry.elements?[elementIdx] {
                    anElement.setPublishAddress(modelPublicationStatusData.publishAddress, forModelId: aModel)
                    aNodeEntry.elements?.remove(at: elementIdx)
                    aNodeEntry.elements?.insert(anElement, at: elementIdx)
                }
                //and update
                state.provisionedNodes.remove(at: anIndex)
                state.provisionedNodes.insert(aNodeEntry, at: anIndex)
                meshstateManager.saveState()
                meshstateManager.restoreState()
                let targetNodeToUpdate = nodeEntry.nodeUnicast!
                nodeEntry = meshstateManager.state().provisionedNodes.first { (aNode) -> Bool in
                    return aNode.nodeUnicast == targetNodeToUpdate
                }
            }
            tableView.reloadData()
        } else {
            handleAlertForStatusCode(modelPublicationStatusData.statusCode)
            print("Failed. Status code: \(modelPublicationStatusData.statusCode)")
        }
    }

    func receivedModelSubsrciptionStatus(_ modelSubscriptionStatusData: ModelSubscriptionStatusMessage) {
        guard lastSubscriptionAction != nil else {
            print("Unknown type of subscription action...")
            return
        }
        if modelSubscriptionStatusData.statusCode == .success {
            print("Subscription address changed!")
            print("Subscription Address: \(modelSubscriptionStatusData.subscriptionAddress.hexString())")
            print("Element Addr: \(modelSubscriptionStatusData.elementAddress.hexString())")
            print("ModelIdentifier: \(modelSubscriptionStatusData.modelIdentifier.hexString())")
            print("Source addr: \(modelSubscriptionStatusData.sourceAddress.hexString())")
            print("Status code: \(modelSubscriptionStatusData.statusCode)")
            
            // Update state with configured subscription addr
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let state = meshstateManager.state()

            if let anIndex = state.provisionedNodes.index(where: { $0.nodeUnicast == nodeEntry.nodeUnicast}) {
                let aNodeEntry = state.provisionedNodes[anIndex]
                if var anElement = aNodeEntry.elements?[elementIdx] {
                    if lastSubscriptionAction! == .subscriptionAdd {
                        anElement.addSubscriptionAddress(modelSubscriptionStatusData.subscriptionAddress, forModelId: aModel)
                    } else {
                        anElement.removeSubscriptionAddress(modelSubscriptionStatusData.subscriptionAddress, forModelId: aModel)
                    }
                    aNodeEntry.elements?.remove(at: elementIdx)
                    aNodeEntry.elements?.insert(anElement, at: elementIdx)
                }
                state.provisionedNodes.remove(at: anIndex)
                state.provisionedNodes.insert(aNodeEntry, at: anIndex)
                meshstateManager.saveState()
                meshstateManager.restoreState()
                let targetNodeToUpdate = nodeEntry.nodeUnicast!
                nodeEntry = meshstateManager.state().provisionedNodes.first { (aNode) -> Bool in
                    return aNode.nodeUnicast == targetNodeToUpdate
                }
            }
            tableView.reloadData()
        } else {
            handleAlertForStatusCode(modelSubscriptionStatusData.statusCode)
            print("Failed. Status code: \(modelSubscriptionStatusData.statusCode)")
        }
        lastSubscriptionAction = nil
    }

    func receivedDefaultTTLStatus(_ defaultTTLStatusData: DefaultTTLStatusMessage) {
        //NOOP
    }

    func configurationSucceeded() {
        //NOOP
    }

    // MARK: - UIViewController
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if companyName != nil {
            vendorLabel.text = "Vendor: \(companyName!) (\(companyIdentifier!.hexString()))"
        } else {
            vendorLabel.text = "SIG Model"
        }
    }

    override func viewDidLoad() {
        if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
            let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
            if targetModel == Data([0x13, 0x00]) {
                //Generic OnOff has section for status and control
                setupLightnessUI()
            } else if targetModel == Data([0x13, 0x07]) {
                setupHSLUI()
            } else if targetModel == Data([0x02, 0x11, 0x00, 0x00]) {
                setupCustomDataUI()
            } else if targetModel == Data([0x02, 0x11, 0x00, 0x01]) {
                setupControllerAllUI()
            }
        }
    }
    
    // MARK: - Controller All Part
    func setupControllerAllUI(){
        let screenw = UIScreen.main.bounds.size.width;
        
        let footView = UIView(frame:CGRect(x:0,y:0,width:screenw,height:200))
        footView.backgroundColor = UIColor.white;
        
        let sw = UISwitch(frame: CGRect(x:100,y:13,width:60,height:20))
        sw.addTarget(self, action: #selector(turnOnOff(sw:)), for: UIControlEvents.valueChanged)
        footView.addSubview(sw);
        
        let slider = UISlider(frame:CGRect(x:20,y:60,width:screenw - 40,height:20))
        slider.isContinuous = false;
        slider.minimumValue = 1.0
        slider.maximumValue = 65535
        slider.addTarget(self, action: #selector(changedAll(slider:)), for: UIControlEvents.valueChanged)
        footView.addSubview(slider);
        
        let redButton = UIButton(frame:CGRect(x:20,y:100,width:60,height:30))
        redButton.backgroundColor = UIColor.red;
        redButton.tag = 1;
        redButton.addTarget(self, action: #selector(clickAllButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(redButton);
        
        let greenButton = UIButton(frame:CGRect(x:screenw / 2 - 30,y:100,width:60,height:30))
        greenButton.backgroundColor = UIColor.green;
        greenButton.tag = 2;
        greenButton.addTarget(self, action: #selector(clickAllButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(greenButton);
        
        let blueButton = UIButton(frame:CGRect(x:screenw - 90,y:100,width:60,height:30))
        blueButton.backgroundColor = UIColor.blue;
        blueButton.tag = 3;
        blueButton.addTarget(self, action: #selector(clickAllButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(blueButton);
        
        let yellowButton = UIButton(frame:CGRect(x:20,y:150,width:60,height:30))
        yellowButton.backgroundColor = UIColor.yellow;
        yellowButton.tag = 4;
        yellowButton.addTarget(self, action: #selector(clickAllButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(yellowButton);
        
        let cyanButton = UIButton(frame:CGRect(x:screenw / 2 - 30,y:150,width:60,height:30))
        cyanButton.backgroundColor = UIColor.cyan;
        cyanButton.tag = 5;
        cyanButton.addTarget(self, action: #selector(clickAllButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(cyanButton);
        
        let magentaButton = UIButton(frame:CGRect(x:screenw - 90,y:150,width:60,height:30))
        magentaButton.backgroundColor = UIColor.magenta;
        magentaButton.tag = 6;
        magentaButton.addTarget(self, action: #selector(clickAllButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(magentaButton);
        
        self.tableView.tableFooterView = footView;
    }
    
    @objc func turnOnOff(sw:UISwitch){
        let targetstate: Data = sw.isOn ? Data([0x01]) : Data([0x00])
        
        let elementIdx = selectedModelIndexPath.section
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        let broadcastAddress = Data([0xFF,0xFF])
        
        targetNode.nodeGenericOnOffSet(elementAddress, onDestinationAddress: broadcastAddress, withtargetState: targetstate)
    }
    
    @objc func changedAll(slider:UISlider){
        print("slider.value = %d",slider.value)
        var intNumber = 0
        intNumber = Int(slider.value)
        let low = UInt8((intNumber & 0xFF))
        let high = UInt8((intNumber >> 8) & 0xFF)
        let targetstate = Data([low, high])
        let elementIdx = selectedModelIndexPath.section
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        let broadcastAddress = Data([0xFF,0xFF])
        
        
        targetNode.nodeGenericSetLightness(elementAddress, onDestinationAddress: broadcastAddress, withtargetState: targetstate)
    }
    
    @objc func clickAllButton(_ button:UIButton){
        var h = 0
        var s = 0
        var l = 0
        
        if button.tag == 1 {
            h = 0
            s = 100
            l = 50
        } else if button.tag == 2 {
            h = 120
            s = 100
            l = 50
        } else if button.tag == 3 {
            h = 240
            s = 100
            l = 50
        } else if button.tag == 4 {
            h = 60
            s = 100
            l = 50
        } else if button.tag == 5 {
            h = 180
            s = 100
            l = 50
        } else if button.tag == 6 {
            h = 300
            s = 100
            l = 50
        }
        
        let hValue = (h * 65535) / 360;
        let sValue = (s * 65535) / 100;
        let lValue = (l * 65535) / 100;
        
        let hlow = UInt8((hValue & 0xFF))
        let hhigh = UInt8((hValue >> 8) & 0xFF)
        
        let slow = UInt8((sValue & 0xFF))
        let shigh = UInt8((sValue >> 8) & 0xFF)
        
        let llow = UInt8((lValue & 0xFF))
        let lhigh = UInt8((lValue >> 8) & 0xFF)
        
        let targetstate = Data([llow, lhigh, hlow, hhigh, slow, shigh])
        let elementIdx = selectedModelIndexPath.section
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        let broadcastAddress = Data([0xFF,0xFF])
        
        targetNode.nodeGenericSetHSL(elementAddress, onDestinationAddress: broadcastAddress, withtargetState: targetstate)
    }
    
    // MARK: - CustomData Part
    func setupCustomDataUI() {
        let screenw = UIScreen.main.bounds.size.width;
        
        let footView = UIView(frame:CGRect(x:0,y:0,width:screenw,height:500))
        footView.backgroundColor = UIColor.white;
        
        let label1 = UILabel(frame:CGRect(x:20,y:13,width:100,height:20));
        label1.text = "High";
        footView.addSubview(label1);
        
        let slider1 = UISlider(frame:CGRect(x:120,y:13,width:screenw - 150,height:20))
        slider1.isContinuous = false;
        slider1.minimumValue = 1.0
        slider1.maximumValue = 100
        slider1.value = 90
        slider1.tag = 101
        msilder1 = slider1
        slider1.addTarget(self, action: #selector(changedLightness(_:)), for: UIControlEvents.valueChanged)
        footView.addSubview(slider1);
        
        let label2 = UILabel(frame:CGRect(x:20,y:56,width:100,height:20));
        label2.text = "Low";
        footView.addSubview(label2);
        
        let slider2 = UISlider(frame:CGRect(x:120,y:56,width:screenw - 150,height:20))
        slider2.isContinuous = false;
        slider2.minimumValue = 1.0
        slider2.maximumValue = 100
        slider2.value = 10
        slider1.tag = 102
        
        msilder2 = slider2
        slider2.addTarget(self, action: #selector(changedLightness(_:)), for: UIControlEvents.valueChanged)
        footView.addSubview(slider2);
        
        let label3 = UILabel(frame:CGRect(x:20,y:99,width:100,height:20));
        label3.text = "Delaytime";
        footView.addSubview(label3);
        
        let textField = UITextField(frame:CGRect(x:120,y:99,width:100,height:20))
        textField.text = "120"
        textField.textColor = UIColor.white
        textField.backgroundColor = UIColor.gray
        mtextField = textField
        footView.addSubview(textField);
        
        let setButton = UIButton(frame:CGRect(x:screenw / 2 - 90,y:140,width:60,height:30))
        setButton.setTitle("Set", for: UIControlState.normal)
        setButton.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 1), for: UIControlState.normal)
        setButton.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 0.5), for: UIControlState.highlighted)
        setButton.tag = 1;
        setButton.addTarget(self, action: #selector(clickButton1(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(setButton);
        
        let getButton = UIButton(frame:CGRect(x:screenw / 2 + 30,y:140,width:60,height:30))
        getButton.setTitle("Get", for: UIControlState.normal)
        getButton.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 1), for: UIControlState.normal)
        getButton.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 0.5), for: UIControlState.highlighted)
        getButton.tag = 2;
        getButton.addTarget(self, action: #selector(clickButton1(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(getButton);
        
        let label4 = UILabel(frame:CGRect(x:20,y:190,width:100,height:20));
        label4.text = "GroupID";
        footView.addSubview(label4);
        
        let textField1 = UITextField(frame:CGRect(x:120,y:190,width:100,height:20))
        textField1.text = "1"
        textField1.textColor = UIColor.white
        textField1.backgroundColor = UIColor.gray
        mtextField1 = textField1
        footView.addSubview(textField1);
        
        let setButton1 = UIButton(frame:CGRect(x:screenw / 2 - 90,y:230,width:60,height:30))
        setButton1.setTitle("Set", for: UIControlState.normal)
        setButton1.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 1), for: UIControlState.normal)
        setButton1.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 0.5), for: UIControlState.highlighted)
        setButton1.tag = 3;
        setButton1.addTarget(self, action: #selector(clickButton2(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(setButton1);
        
        let getButton2 = UIButton(frame:CGRect(x:screenw / 2 + 30,y:230,width:60,height:30))
        getButton2.setTitle("Get", for: UIControlState.normal)
        getButton2.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 1), for: UIControlState.normal)
        getButton2.setTitleColor(UIColor.init(red: 0, green: 0, blue: 255, alpha: 0.5), for: UIControlState.highlighted)
        getButton2.tag = 4;
        getButton2.addTarget(self, action: #selector(clickButton2(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(getButton2);
        
        let tapGes = UITapGestureRecognizer(target: self, action: #selector(tapGesAction(_:)))
        tapGes.delegate = self
        footView.addGestureRecognizer(tapGes)
        
        self.tableView.tableFooterView = footView;
    }
    
    // 方法
    @objc func tapGesAction(_ tapGes : UITapGestureRecognizer){
        mtextField.resignFirstResponder()
        mtextField1.resignFirstResponder()
    }
    
    @objc func changedLightness(_ slider:UISlider){
        print("slider.value = %d",slider.value)
        var intNumber = 0
        intNumber = Int(slider.value)
        
        intNumber = intNumber * 65535 / 100
        let low = UInt8((intNumber & 0xFF))
        let high = UInt8((intNumber >> 8) & 0xFF)
        let targetstate = Data([low, high])
        let elementIdx = selectedModelIndexPath.section
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        
        targetNode.nodeGenericSetLightness(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!, withtargetState: targetstate)
    }
    
    @objc func clickButton1(_ button:UIButton){
        
        if button.tag == 1 {
            
            let l1 = UInt8(msilder1.value)
            let l2 = UInt8(msilder2.value)
            let value = Int(mtextField.text!)
            let low = UInt8((value! & 0xFF))
            let high = UInt8((value! >> 8) & 0xFF)
            
            let targetstate = Data([l1, l2, low, high])
            let elementIdx = selectedModelIndexPath.section
            let unicast = nodeEntry.nodeUnicast!
            let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
            
            targetNode.nodeGenericSetCustom(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!, withtargetState: targetstate)
        } else {
            let elementIdx = selectedModelIndexPath.section
            let unicast = nodeEntry.nodeUnicast!
            let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
            
            targetNode.nodeGenericGetCustom(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!)
        }
    }
    
    @objc func clickButton2(_ button:UIButton){
        
        if button.tag == 3 {
            let value = Int(mtextField1.text!)
            let low = UInt8((value! & 0xFF))
//            let high = UInt8((value! >> 8) & 0xFF)
            
            let targetstate = Data([0xC0, low])
            let elementIdx = selectedModelIndexPath.section
            let unicast = nodeEntry.nodeUnicast!
            let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
            
            targetNode.nodeGenericSetGroup(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!, withtargetState: targetstate)
        } else {
            let elementIdx = selectedModelIndexPath.section
            let unicast = nodeEntry.nodeUnicast!
            let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
            
            targetNode.nodeGenericGetGroup(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!)
        }
    }
    
    // MARK: - Lightness Part
    func setupLightnessUI(){
        let screenw = UIScreen.main.bounds.size.width;
        
        let footView = UIView(frame:CGRect(x:0,y:0,width:screenw,height:50))
        footView.backgroundColor = UIColor.white;
        
        let slider = UISlider(frame:CGRect(x:20,y:13,width:screenw - 40,height:20))
        slider.isContinuous = false;
        slider.minimumValue = 1.0
        slider.maximumValue = 65535
        slider.addTarget(self, action: #selector(changed(slider:)), for: UIControlEvents.valueChanged)
        footView.addSubview(slider);
        
        self.tableView.tableFooterView = footView;
    }
    
    @objc func changed(slider:UISlider){
        print("slider.value = %d",slider.value)
        var intNumber = 0
        intNumber = Int(slider.value)
        let low = UInt8((intNumber & 0xFF))
        let high = UInt8((intNumber >> 8) & 0xFF)
        let targetstate = Data([low, high])
        let elementIdx = selectedModelIndexPath.section
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        
        targetNode.nodeGenericSetLightness(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!, withtargetState: targetstate)
    }
    
    // MARK: - HSL Part
    func setupHSLUI(){
        let screenw = UIScreen.main.bounds.size.width;
        
        let footView = UIView(frame:CGRect(x:0,y:0,width:screenw,height:100))
        footView.backgroundColor = UIColor.white;
        
        let redButton = UIButton(frame:CGRect(x:20,y:10,width:60,height:30))
        redButton.backgroundColor = UIColor.red;
        redButton.tag = 1;
        redButton.addTarget(self, action: #selector(clickButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(redButton);
        
        let greenButton = UIButton(frame:CGRect(x:screenw / 2 - 30,y:10,width:60,height:30))
        greenButton.backgroundColor = UIColor.green;
        greenButton.tag = 2;
        greenButton.addTarget(self, action: #selector(clickButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(greenButton);
        
        let blueButton = UIButton(frame:CGRect(x:screenw - 90,y:10,width:60,height:30))
        blueButton.backgroundColor = UIColor.blue;
        blueButton.tag = 3;
        blueButton.addTarget(self, action: #selector(clickButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(blueButton);
        
        let yellowButton = UIButton(frame:CGRect(x:20,y:60,width:60,height:30))
        yellowButton.backgroundColor = UIColor.yellow;
        yellowButton.tag = 4;
        yellowButton.addTarget(self, action: #selector(clickButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(yellowButton);
        
        let cyanButton = UIButton(frame:CGRect(x:screenw / 2 - 30,y:60,width:60,height:30))
        cyanButton.backgroundColor = UIColor.cyan;
        cyanButton.tag = 5;
        cyanButton.addTarget(self, action: #selector(clickButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(cyanButton);
        
        let magentaButton = UIButton(frame:CGRect(x:screenw - 90,y:60,width:60,height:30))
        magentaButton.backgroundColor = UIColor.magenta;
        magentaButton.tag = 6;
        magentaButton.addTarget(self, action: #selector(clickButton(_:)), for: UIControlEvents.touchUpInside)
        
        footView.addSubview(magentaButton);
        
        self.tableView.tableFooterView = footView;
    }
    
    @objc func clickButton(_ button:UIButton){
        var h = 0
        var s = 0
        var l = 0
        
        if button.tag == 1 {
            h = 0
            s = 100
            l = 50
        } else if button.tag == 2 {
            h = 120
            s = 100
            l = 50
        } else if button.tag == 3 {
            h = 240
            s = 100
            l = 50
        } else if button.tag == 4 {
            h = 60
            s = 100
            l = 50
        } else if button.tag == 5 {
            h = 180
            s = 100
            l = 50
        } else if button.tag == 6 {
            h = 300
            s = 100
            l = 50
        }
        
        let hValue = (h * 65535) / 360;
        let sValue = (s * 65535) / 100;
        let lValue = (l * 65535) / 100;
        
        let hlow = UInt8((hValue & 0xFF))
        let hhigh = UInt8((hValue >> 8) & 0xFF)
        
        let slow = UInt8((sValue & 0xFF))
        let shigh = UInt8((sValue >> 8) & 0xFF)
        
        let llow = UInt8((lValue & 0xFF))
        let lhigh = UInt8((lValue >> 8) & 0xFF)
        
        let targetstate = Data([llow, lhigh, hlow, hhigh, slow, shigh])
        let elementIdx = selectedModelIndexPath.section
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        
        targetNode.nodeGenericSetHSL(elementAddress, onDestinationAddress: nodeEntry.nodeUnicast!, withtargetState: targetstate)
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            if indexPath.section == 0 {
                //App key unbinding
                self.didSelectUnbindAppKeyAtIndex(UInt16(indexPath.row))
            } else  if indexPath.section == 2 {
                //Subscription addresses
                if let nodeAddress = self.getSubscriptionAddressforNodeAtIndexPath(indexPath) {
                    print("Deleting subscription address: \(nodeAddress.hexString())")
                    self.didSelectSubscriptionAddressDelete(nodeAddress)
                }
            }
        case .none, .insert:
            //NOOP
            break
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            //App Key binding is editable, all rows can be tapped or swiped to remove
            //only if it has an appkey set to that row, we mark that using the tags for now
            if tableView.cellForRow(at: indexPath)?.tag == 1 {
                return true
            } else {
                return false
            }
        } else if indexPath.section == 2 {
            //First row is the subscription add button, it cannot be edited
            return indexPath.row != 0
        } else {
            //No other known rows are editable, disable by default
            return false
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
            let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
            if targetModel == Data([0x10, 0x00]) {
                //Generic OnOff has section for status and control
                return 4
            }
        }
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 1
        case 2:
            //Get number of subscription addresses to render
            if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
                let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
                if let subscriptions = element.subscriptionAddressesForModelId(targetModel) {
                    if subscriptions.count > 0 {
                        return subscriptions.count + 1
                    }
                }
            }
            return 1
        case 3:
            // if GenericOnOff is present, return 1 row for the control section
            return 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "AppKey Binding"
        } else if section == 1 {
            return "Publication Address"
        } else if section == 2 {
            return "Subscription Addresses"
        } else if section == 3 {
            return "Node Control"
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var aCell: UITableViewCell!
        if indexPath.section == 3 && indexPath.row == 0 {
            aCell = tableView.dequeueReusableCell(withIdentifier: "ModelConfigurationToggleCell", for: indexPath)
            if let aCell = aCell as? ToggleControlTableViewCell {
                //Receive toggle switch events
                aCell.delegate = self
                
                //Enable/disable cell depending on bound appkey state
                if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
                    let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
                    aCell.toggleSwitch.isEnabled = element.boundAppKeyIndexForModelId(targetModel) != nil
                    if aCell.toggleSwitch.isEnabled == false {
                        aCell.setTitle(aTitle: "Appkey not bound")
                    } else {
                        aCell.setTitle(aTitle: "GenericOnOff state")
                    }
                }
            }
        } else if indexPath.section == 2 && indexPath.row == 0 {
            aCell = tableView.dequeueReusableCell(withIdentifier: "ModelConfigurationCenteredCell", for: indexPath)
        } else {
            aCell = tableView.dequeueReusableCell(withIdentifier: "ModelConfigurationCell", for: indexPath)
        }

        if indexPath.section == 0 {
            if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
                let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
                if let keyIndex = element.boundAppKeyIndexForModelId(targetModel) {
                    aCell.tag = 1
                    aCell.textLabel?.text = "Key Bound"
                    aCell.detailTextLabel?.text = "Key index \(keyIndex.hexString())"
                } else {
                    aCell.tag = 0
                    aCell.textLabel?.text = "None"
                    aCell.detailTextLabel?.text = "Tap to add"
                }
            }
            return aCell
        }
        
        if indexPath.section == 1 {
            if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
                let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
                if let address = element.publishAddressForModelId(targetModel) {
                    let addressType = MeshAddressTypes(rawValue: address)
                    if addressType! == .Unassigned {
                        aCell.textLabel?.text = "None"
                        aCell.detailTextLabel?.text = "Tap to add"
                    } else {
                        aCell.textLabel?.text = address.hexString()
                        aCell.detailTextLabel?.text = "Tap to change or remove"
                    }
                } else {
                    aCell.textLabel?.text = "None"
                    aCell.detailTextLabel?.text = "Tap to add"
                }
            }
            return aCell
        }
        
        if indexPath.section == 2 {
            if indexPath.row == 0 {
                aCell.textLabel?.text = "Add Subscription Address"
            } else {
                if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
                    let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
                    if let addresses = element.subscriptionAddressesForModelId(targetModel) {
                        if addresses.count > 0 {
                            aCell.textLabel?.text = addresses[indexPath.row - 1].hexString()
                            if let addressType = MeshAddressTypes(rawValue: addresses[indexPath.row - 1]) {
                                var addressText: String?
                                switch addressType {
                                case .Unassigned:
                                    addressText = "Unassigned address"
                                case .Group:
                                    addressText = "Group address"
                                case .Broadcast:
                                    addressText = "Broadcast address"
                                case .Unicast:
                                    addressText = "Unicast address"
                                case .Virtual:
                                    addressText = "Virtual address"
                                }
                                aCell.detailTextLabel?.text = addressText
                            } else {
                                aCell.detailTextLabel?.text = nil
                            }
                            aCell.accessoryType = .none
                        }
                    }
                }
            }
            return aCell
        }
        return aCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            self.performSegue(withIdentifier: "showAppKeySelector", sender: nil)
        case 1:
            self.performSegue(withIdentifier: "ShowPublicationSettings", sender: nil)
        case 2:
            if indexPath.row == 0 {
                self.presentInputAlert(withResetCapability: false) { (anAddressString) in
                    guard  anAddressString != nil else {
                        return
                    }
                    if let addressData = Data(hexString: anAddressString!) {
                        self.didSelectSubscriptionAddressAdd(addressData)
                    }
                }
            }
        default:
            break
        }
    }

    // MARK: - Input Alerts
    func presentInputAlert(withResetCapability canReset: Bool, andCompletion aCompletionHandler : @escaping (String?) -> Void) {
        let inputAlertView = UIAlertController(title: "Enter an address",
                                               message: nil,
                                               preferredStyle: .alert)
        inputAlertView.addTextField { (aTextField) in
            aTextField.keyboardType = UIKeyboardType.alphabet
            aTextField.returnKeyType = .done
            aTextField.delegate = self
            aTextField.clearButtonMode = UITextFieldViewMode.whileEditing
            //Give a placeholder that shows this upcoming key index
            aTextField.placeholder = "0001"
        }

        let addAction = UIAlertAction(title: "Add", style: .default) { (_) in
            DispatchQueue.main.async {
                if var text = inputAlertView.textFields![0].text {
                    if text.lowercased().contains("0x") {
                        text = text.lowercased().replacingOccurrences(of: "0x", with: "")
                    }
                    if text.count == 4 {
                        aCompletionHandler(text)
                    } else {
                        aCompletionHandler(nil)
                    }
                } else {
                    aCompletionHandler(nil)
                }
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            DispatchQueue.main.async {
                aCompletionHandler(nil)
            }
        }

        inputAlertView.addAction(addAction)
        
        if canReset {
            //Some fields can be resettable, this adds a reset button
            let clearAction = UIAlertAction(title: "Clear", style: .destructive) { (_) in
                DispatchQueue.main.async {
                    aCompletionHandler("reset")
                }
            }
            inputAlertView.addAction(clearAction)
        }

        inputAlertView.addAction(cancelAction)
        present(inputAlertView, animated: true, completion: nil)
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if var text = textField.text {
            if text.lowercased().contains("0x") {
                text = text.lowercased().replacingOccurrences(of: "0x", with: "")
            }
            //Valid address in textfield
            return text.count == 4
        } else {
            //No address in textfield
            return false
        }
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if range.length > 0 {
            //Going backwards, always allow deletion
            return true
        } else {
            let value = string.data(using: .utf8)![0]
            //Only allow HexaDecimal values 0->9, a->f and A->F or x
            return (value == 120 || value >= 48 && value <= 57) || (value >= 65 && value <= 70) || (value >= 97 && value <= 102)
        }
    }

    // MARK: - PublicationSettingsDelegate
    func didDisablePublication() {
        let elementIdx = selectedModelIndexPath.section
        let modelIdx = selectedModelIndexPath.row
        let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        targetNode.nodePublicationAddressSet(Data([0x00,0x00]),
                                             onElementAddress: elementAddress,
                                             appKeyIndex: Data([0x00, 0x00]),
                                             credentialFlag: false,
                                             ttl: Data([0x00]),
                                             period: Data([0x00]),
                                             retransmitCount: Data([0x00]),
                                             retransmitInterval: Data([0x00]),
                                             modelIdentifier: aModel,
                                             onDestinationAddress: nodeEntry.nodeUnicast!)

        self.navigationController?.popViewController(animated: true)
    }

    func didSavePublicatoinConfiguration(withAddress anAddress: Data, appKeyIndex anAppKeyIndex: UInt16, credentialFlag aCredentialFlag: Bool, ttl aTTL: UInt8, publishPeriod aPublishPeriod: UInt8, retransmitCount aRetransmitCoutn: UInt8, retransmitIntervalSteps aRetransmitIntervalStep: UInt8) {
        
        let elementIdx = selectedModelIndexPath.section
        let modelIdx = selectedModelIndexPath.row
        let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        var anIndex = anAppKeyIndex.bigEndian
        let appKeyIndexData = Data(bytes: &anIndex, count: MemoryLayout<UInt16>.size)
        targetNode.nodePublicationAddressSet(anAddress,
                                             onElementAddress: elementAddress,
                                             appKeyIndex: appKeyIndexData,
                                             credentialFlag: aCredentialFlag,
                                             ttl: Data([aTTL]),
                                             period: Data([aPublishPeriod]),
                                             retransmitCount: Data([aRetransmitCoutn]),
                                             retransmitInterval: Data([aRetransmitIntervalStep]),
                                             modelIdentifier: aModel,
                                             onDestinationAddress: nodeEntry.nodeUnicast!)

        self.navigationController?.popViewController(animated: true)
    }

    // MARK: - Navigation
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return ["showAppKeySelector",
                "ShowPublicationSettings"].contains(identifier)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAppKeySelector" {
            if let destination = segue.destination as? AppKeySelectorTableViewController {
                destination.setSelectionCallback({ (selectedIndex) in
                    if selectedIndex != nil  {
                        self.didSelectAppKeyAtIndex(UInt16(selectedIndex!))
                    }
                }, andMeshStateManager: meshstateManager)
            }
        }
        if segue.identifier == "ShowPublicationSettings" {
            if let destination = segue.destination as? ModelPublicationConfigurationTableViewController {
                destination.setDelegate(self)
                destination.setStateManager(meshstateManager)
            }
        }
    }

    // MARK: - Helpers
    private func getSubscriptionAddressforNodeAtIndexPath(_ anIndexPath: IndexPath) -> Data? {
        if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
            let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
            if let addresses = element.subscriptionAddressesForModelId(targetModel) {
                if addresses.count > anIndexPath.row - 1 {
                    return addresses[anIndexPath.row - 1]
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        return nil
    }
}

//
//  ARViewModel.swift
//  FaceDetectionApp
//
//  Created by Mehmet Koca on 7/24/18.
//  Copyright © 2018 Mehmet Koca. All rights reserved.
//

import Foundation
import Vision
import ARKit

final class ARViewModel {
    
    private let state: ARState
    private let dataController = DataController()
    private var currentBuffer: CVPixelBuffer?
    private let visionQueue = DispatchQueue(label: "visionQueue")
    var bounds: CGRect?
    var cardDictionary = [String : SCNNode]()
    var planeNode: SCNNode?
    var commencers: [Commencer]?
    var commencer: Commencer?
    var sceneView: ARSCNView?
    var currentNode: SCNNode? {
        get {
            return self.state.node
        }
        set {
            self.state.node?.removeFromParentNode()
            self.state.node = newValue
        }
    }
    
    var stateChangeHandler: ((ARState.Change) -> Void)? {
        get { return state.onChange }
        set { state.onChange = newValue }
    }
    
    private var imageOriantation: CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }
    
    init(sceneView: ARSCNView) {
        self.state = ARState()
        self.sceneView = sceneView
        self.bounds = sceneView.bounds
    }

    func takeCapturedImage(from frame: ARFrame) {
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
            return
        }
        
        self.currentBuffer = frame.capturedImage
        classifyCurrentImage()
    }
    
    private func classifyCurrentImage() {
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: currentBuffer!, orientation: imageOriantation)
        visionQueue.async {
            do {
                defer { self.currentBuffer = nil }
                try requestHandler.perform([self.classificationRequest])
            } catch {
                print("image request error")
            }
        }
    }
    
    private lazy var classificationRequest: VNDetectFaceRectanglesRequest = {
        do {
            let model = try VNCoreMLModel(for: Commencers().model)
            let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
                if let face = request.results?.first as? VNFaceObservation {
                    let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] (request, error) in
                        self?.processClassification(for: request, error: error)
                    })
                    request.imageCropAndScaleOption = .centerCrop
                    request.usesCPUOnly = true
                    let handler = VNImageRequestHandler(cvPixelBuffer: self.currentBuffer!, options: [:])
                    try? handler.perform([request])
                    let boundingBox = self.transformBoundingBox(face.boundingBox)
                    guard let worldCoordination = self.normalizeWorldCoord(boundingBox),
                        let commencerName = self.commencer?.name else { return }
                     guard let _ = self.cardDictionary[commencerName] else {
                        DispatchQueue.main.async{
                            self.currentNode = self.createCard(facePosition: worldCoordination, commencer: self.commencer)
                        }
                        return
                    }
                }
                else {
                    self.cardDictionary = [:]
                }
            })
            return detectFaceRequest
        } catch  {
            fatalError("Failed to load  ML model: \(error)")
        }
    }()
    
    func processClassification (for request: VNRequest, error: Error?){
        guard let results = request.results else {
            print("Unable to classify image.\n\(error!.localizedDescription)")
            return
        }
        
        let classifications = results as! [VNClassificationObservation]
        
        if let bestResult = classifications.first(where: { result in result.confidence > 0.35}) {
            self.commencers = dataController.loadJson("Commencers")!
            self.commencers?.forEach({ (commencer) in
                if commencer.name == bestResult.identifier {
                    self.commencer = commencer
                }
            })
        }
    }
    
    func createPlane() -> SCNNode {
        let plane = SCNPlane(width: Constants.cardWidth, height: Constants.cardHeight)
        let cardBackground = SCNMaterial()
        cardBackground.diffuse.contents = "bgCard.png"
        plane.firstMaterial = cardBackground
        plane.cornerRadius = 0.02
        self.planeNode = SCNNode(geometry: plane)
        return planeNode!
    }

    func createCard(facePosition: SCNVector3, commencer: Commencer?) -> SCNNode? {
        guard let name = commencer?.name else { return nil }
        guard let title = commencer?.title else { return nil }
        guard let department = commencer?.department else { return nil }
        if let card = cardDictionary[name] {
            positionCard(card, facePosition)
            return card
        }
        let card = createPlane()
        
        let commencerName = createTextNode(string: "Name: \(name)", scale: Constants.nameTextScale)
        positionText(textNode: commencerName, card: card, heightLevel: 1.0)
        
        let commencerTitle = createTextNode(string: "Title: \(title)", scale: Constants.titleTextScale)
        positionText(textNode: commencerTitle, card: card, heightLevel: 2.0)
        
        let commencerDepartment = createTextNode(string: "Department: \(department)", scale: Constants.departmentTextScale)
        positionText(textNode: commencerDepartment, card: card, heightLevel: 3.0)
        
        positionCard(card, facePosition)
        cardDictionary[name] = card
        
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        card.constraints = [billboardConstraint]
        
        return card
    }
    
    func positionCard(_ card: SCNNode, _ position: SCNVector3) {
        card.position = position
        card.position.x += Constants.cardPositionXOffset
        card.position.y += Constants.cardPositionYOffset
    }
    
    func positionText(textNode: SCNNode, card: SCNNode, heightLevel: Float) {
        let (cardBoundingBoxMin, cardBoundingBoxMax) = card.boundingBox
        let (nameTextBoundingBoxMin, nameTextBoundingBoxMax) = textNode.boundingBox
        textNode.position = card.position
        textNode.position.x = cardBoundingBoxMin.x + ((cardBoundingBoxMax.x - cardBoundingBoxMin.x) - ((nameTextBoundingBoxMax.x - nameTextBoundingBoxMin.x) * Constants.nameTextScale)) / 2
        textNode.position.y = cardBoundingBoxMax.y - heightLevel * Constants.constantSpaceBetweenTextNodes
        card.addChildNode(textNode)
    }
    
    func createTextNode(string: String, scale: Float) -> SCNNode {
        let textGeometry = SCNText(string: string, extrusionDepth: 0.2)
        textGeometry.font = UIFont(name: "Arial", size: 2)
        textGeometry.firstMaterial!.diffuse.contents = UIColor.white
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(scale, scale, scale)
        return textNode
    }
    
    private func normalizeWorldCoord(_ boundingBox: CGRect) -> SCNVector3? {
        
        var array: [SCNVector3] = []
        Array(0...2).forEach{_ in
            if let position = determineWorldCoord(boundingBox) {
                array.append(position)
            }
            usleep(12000)
        }
        
        if array.isEmpty {
            return nil
        }
        
        return SCNVector3.center(array)
    }
    
    private func determineWorldCoord(_ boundingBox: CGRect) -> SCNVector3? {
        let arHitTestResults = sceneView?.hitTest(CGPoint(x: boundingBox.midX, y: boundingBox.midY), types: [.featurePoint])
        
        if let closestResult = arHitTestResults?.filter({ $0.distance > 0.10 }).first {
            return SCNVector3.positionFromTransform(closestResult.worldTransform)
        }
        return nil
    }

    private func transformBoundingBox(_ boundingBox: CGRect) -> CGRect {
        var size: CGSize
        var origin: CGPoint
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight:
            size = CGSize(width: boundingBox.width * (bounds?.height)!,
                          height: boundingBox.height * (bounds?.width)!)
        default:
            size = CGSize(width: boundingBox.width * (bounds?.width)!,
                          height: boundingBox.height * (bounds?.height)!)
        }
        
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            origin = CGPoint(x: boundingBox.minY * (bounds?.width)!,
                             y: boundingBox.minX * (bounds?.height)!)
        case .landscapeRight:
            origin = CGPoint(x: (1 - boundingBox.maxY) * (bounds?.width)!,
                             y: (1 - boundingBox.maxX) * (bounds?.height)!)
        case .portraitUpsideDown:
            origin = CGPoint(x: (1 - boundingBox.maxX) * (bounds?.width)!,
                             y: boundingBox.minY * (bounds?.height)!)
        default:
            origin = CGPoint(x: boundingBox.minX * (bounds?.width)!,
                             y: (1 - boundingBox.maxY) * (bounds?.height)!)
        }
        return CGRect(origin: origin, size: size)
    }
    
}

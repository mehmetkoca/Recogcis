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
    private var currentBuffer: CVPixelBuffer?
    private let visionQueue = DispatchQueue(label: "visionQueue")
    private let textNode: SCNNode?
    private var textGeometry: SCNText?
    var bounds: CGRect?
    
    var sceneView: ARSCNView?
    
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
        
        textGeometry = SCNText(string: "Hello", extrusionDepth: 0.2)
        textGeometry?.font = UIFont(name: "Arial", size: 2)
        textGeometry?.firstMaterial!.diffuse.contents = UIColor.red
        textNode = SCNNode(geometry: textGeometry)
        textNode?.scale = SCNVector3(0.003, 0.003, 0.003)
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
                        let node = self.textNode else { return }
                    let (min, max) = node.boundingBox
                    self.textNode?.constraints = [SCNBillboardConstraint()]
                    node.position = worldCoordination
                    // setting up x position for text scale
                    node.position.x = node.position.x - ((min.x + max.x) / 2) * 0.003
                    self.textGeometry?.string = self.state.identifier
                    self.sceneView?.scene.rootNode.addChildNode(node)
                } else {
                    self.state.identifier = "Investigating..."
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
        
        if let bestResult = classifications.first(where: { result in result.confidence > 0.5}) {
            state.identifier = bestResult.identifier
        }
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
        
        // Filter results that are to close
        if let closestResult = arHitTestResults?.filter({ $0.distance > 0.10 }).first {
            // print("vector distance: \(closestResult.distance)")
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

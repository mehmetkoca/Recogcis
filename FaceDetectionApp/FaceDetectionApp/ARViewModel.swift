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
    
    init() {
        self.state = ARState()
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
}

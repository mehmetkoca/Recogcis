//
//  ARState.swift
//  FaceDetectionApp
//
//  Created by Mehmet Koca on 7/24/18.
//  Copyright © 2018 Mehmet Koca. All rights reserved.
//
import ARKit

final class ARState {
    enum Change {
        case node(SCNNode?)
    }
    
    var onChange: ((ARState.Change) -> Void)?
    
    var node: SCNNode? {
        didSet{ onChange?(.node(node))}
    }
}

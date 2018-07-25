//
//  ARState.swift
//  FaceDetectionApp
//
//  Created by Mehmet Koca on 7/24/18.
//  Copyright © 2018 Mehmet Koca. All rights reserved.
//

final class ARState {
    enum Change {
        case identifier(String?)
    }
    
    var onChange: ((ARState.Change) -> Void)?
    
    var identifier: String? {
        didSet { onChange?(.identifier(identifier)) }
    }
}

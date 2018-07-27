//
//  SCNVector3.swift
//  FaceDetectionApp
//
//  Created by Mehmet Koca on 7/27/18.
//  Copyright © 2018 Mehmet Koca. All rights reserved.
//

import ARKit

extension SCNVector3 {
    /**
     Calculates vector length based on Pythagoras theorem
     */
    var length:Float {
        return sqrtf(x*x + y*y + z*z)
    }
    
    func distance(toVector: SCNVector3) -> Float {
        return (self - toVector).length
    }
    
    static func positionFromTransform(_ transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    static func -(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    static func center(_ vectors: [SCNVector3]) -> SCNVector3 {
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        
        let size = Float(vectors.count)
        vectors.forEach {
            x += $0.x
            y += $0.y
            z += $0.z
        }
        return SCNVector3Make(x / size, y / size, z / size)
    }
}

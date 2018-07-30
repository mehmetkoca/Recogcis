//
//  DataController.swift
//  FaceDetectionApp
//
//  Created by Mehmet Koca on 7/30/18.
//  Copyright © 2018 Mehmet Koca. All rights reserved.
//

import Foundation
class DataController {
    func loadJson(_ fileName: String) -> [Commencer]? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let jsonData = try decoder.decode([Commencer].self, from: data)
                return jsonData
            } catch {
                print("error:\(error)")
            }
        }
        return nil
    }
}

//
//  ErrorPresenter.swift
//  FaceDetectionApp
//
//  Created by Mehmet Koca on 7/25/18.
//  Copyright © 2018 Mehmet Koca. All rights reserved.
//

import UIKit

class ErrorPresenter {
    
    static func showError(message: String, on viewController: UIViewController?, dismissAction: ((UIAlertAction) -> Void)? = nil) {
        weak var vc = viewController
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""),
                                                    message: message,
                                                    preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: .default, handler: dismissAction))
            vc?.present(alertController, animated: true)
        }
    }
}

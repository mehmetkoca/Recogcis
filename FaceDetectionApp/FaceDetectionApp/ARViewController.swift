//
//  ViewController.swift
//  FaceDetectionApp
//
//  Created by Mehmet Koca on 7/23/18.
//  Copyright © 2018 Mehmet Koca. All rights reserved.
//

import UIKit
import ARKit
import Vision

class ARViewController: UIViewController {
    
    @IBOutlet weak var sceneView: ARSCNView!
    
    private var viewModel: ARViewModel!
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepareSceneView()
        

        viewModel = ARViewModel(sceneView: sceneView)
        viewModel.stateChangeHandler = { [weak self] change in
            self?.applyStateChange(change)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func applyStateChange(_ change: ARState.Change) {
        DispatchQueue.main.async {
            switch change {
            case let .node(node):
                guard let node = node else { return }
                self.sceneView.scene.rootNode.addChildNode(node)                
            }
        }
    }
    
    func prepareSceneView() {
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
    }
}

extension ARViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        viewModel.takeCapturedImage(from: frame)
    }
}



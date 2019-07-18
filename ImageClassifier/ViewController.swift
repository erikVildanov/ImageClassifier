//
//  ViewController.swift
//  ImageClassifier
//
//  Created by Erik Vildanov on 17/07/2019.
//  Copyright © 2019 Erik Vildanov. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {
    
    let model = ImageClassifier()
    var frameExtractor: FrameExtractor!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var currentObjLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        // Do any additional setup after loading the view.
    }
}

extension ViewController: FrameExtractorDelegate {
    func captured(image: UIImage) {
        imageView.image = image
    }
    
    func pixelBufer(cvPixelBuffer: CVPixelBuffer) {
        DispatchQueue.global(qos: .default).async {
            guard let prediction = try? self.model.prediction(image: cvPixelBuffer) else { return }
            let classLabelProbs = prediction.classLabelProbs.first
            if Int(classLabelProbs!.value * 100) < 70 { return }
            DispatchQueue.main.async {
                self.currentObjLabel.text = "\(classLabelProbs!.key) : \(Int(classLabelProbs!.value * 100))"
            }
        }
    }
}

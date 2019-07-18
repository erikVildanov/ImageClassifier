//
//  FrameExtractor.swift
//  ImageClassifier
//
//  Created by Erik Vildanov on 17/07/2019.
//  Copyright © 2019 Erik Vildanov. All rights reserved.
//

import UIKit
import AVFoundation

protocol FrameExtractorDelegate: class {
    func captured(image: UIImage)
    func pixelBufer(cvPixelBuffer: CVPixelBuffer)
}

class  FrameExtractor: NSObject {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var permissionGranted = false
    private let context = CIContext()
    private let position = AVCaptureDevice.Position.back
    private let quality = AVCaptureSession.Preset.medium
    
    weak var delegate: FrameExtractorDelegate?
    
    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.configureSession()
            self.captureSession.startRunning()
        }
    }
    
    // MARK: AVSession configuration
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    private func configureSession() {
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice() else { return }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = false
    }
    
    private func selectCaptureDevice() -> AVCaptureDevice? {
//        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: position).devices.first
        return AVCaptureDevice.devices().filter {
            ($0 as AnyObject).hasMediaType(AVMediaType.video) &&
                ($0 as AnyObject).position == position
            }.first
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer =  CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        delegate?.pixelBufer(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
}

extension FrameExtractor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async { [unowned self] in
            guard let uiImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
            self.delegate?.captured(image: uiImage)
        }
    }
}

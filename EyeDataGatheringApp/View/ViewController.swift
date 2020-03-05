//
//  ViewController.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 08.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import SnapKit
import RxCocoa
import RxSwift
import AVFoundation

class ViewController: UIViewController {
    
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    var windowOrientation: UIInterfaceOrientation {
        return view.window?.windowScene?.interfaceOrientation ?? .unknown
    }
    
    // Neccesary elements on the screen
    var preview: PreviewView!
    var capture: UIButton!
    var timeLapsed: UILabel!
    var frameView: UIView!
    var flash: UIButton!
    
    // Video Session variables
    let session = AVCaptureSession()
    private var isSessionRunning = false
    var movieOutput = AVCaptureMovieFileOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    private var setupResult: SessionSetupResult = .success
    
    // Reactive dispose bag
    let disposeBag = DisposeBag()
    // ViewModel variable
    private var viewModel: RecordingViewModelProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureScreen()
        
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session if setup succeeded.
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let connection = self.preview.videoPreviewLayer.connection {
            let currentDevice: UIDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection : AVCaptureConnection = connection

            if (previewLayerConnection.isVideoOrientationSupported) {
                switch (orientation) {
                case .portrait:
                    previewLayerConnection.videoOrientation = .portrait
                case .landscapeRight:
                    previewLayerConnection.videoOrientation = .landscapeLeft
                case .landscapeLeft:
                    previewLayerConnection.videoOrientation = .landscapeRight

                default:
                    previewLayerConnection.videoOrientation = AVCaptureVideoOrientation.portrait
                }
            }
        }
    }
    
    private func configureScreen() -> Void {
        // Setup Video preview screen
        preview = PreviewView()
        self.view.addSubview(preview)
        preview.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
        preview.session = session
        
        // Video Capture button setup
        capture = UIButton()
        capture.setImage(UIImage(named: "Capture"), for: .normal)
        self.view.addSubview(capture)
        capture.snp.makeConstraints { (make) in
            make.centerX.equalTo(self.view.snp.centerX)
            make.bottom.equalTo(self.view).inset(0)
            make.height.equalTo(75)
            make.width.equalTo(75)
        }
        self.capture.rx.tap
            .debug()
            .subscribe(onNext: { _ in
                self.startRecording()
            })
            .disposed(by: disposeBag)
        
        // Timer label setup
        timeLapsed = UILabel()
        self.view.addSubview(timeLapsed)
        timeLapsed.snp.makeConstraints {make in
            make.centerX.equalTo(self.view.snp.centerX)
            make.top.equalTo(self.view).inset(10)
            make.height.lessThanOrEqualTo(45)
        }
        self.timeLapsed.text = "Starting recording"

        // Inner frame setup + adding tap gesture recognizer
        self.frameView = UIView()
        self.view.addSubview(frameView)
        frameView.snp.makeConstraints { make in
            make.centerX.equalTo(self.view.snp.centerX)
            make.top.equalTo(self.view).inset(65)
            make.bottom.equalTo(self.view).inset(85)
            make.left.equalTo(self.view).inset(20)
            make.right.equalTo(self.view).inset(20)
        }
        self.frameView.backgroundColor = UIColor.clear
        self.frameView.layer.borderColor = UIColor.green.cgColor
        self.frameView.layer.borderWidth = 2.0
        let tapForFocus = UITapGestureRecognizer(target: self, action: #selector( tapToFocus(_:)))
        tapForFocus.numberOfTapsRequired = 1
        self.frameView.addGestureRecognizer(tapForFocus)
        
        // Flash button setup
        self.flash = UIButton()
        self.view.addSubview(flash)
        flash.snp.makeConstraints { make in
            make.left.equalTo(self.view).inset(20)
            make.top.equalTo(self.view).inset(10)
        }
        self.flash.setImage(UIImage(named: "flash_off"), for: .normal)
        self.flash.rx.tap
            .debug()
            .subscribe(onNext: { _ in
                self.startFlash()
            })
            .disposed(by: disposeBag)
    }
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        let movieFileOutput = AVCaptureMovieFileOutput()
        

        session.beginConfiguration()
        
        // Add video input.
        do {
            if self.session.canAddOutput(movieFileOutput) {
                self.session.addOutput(movieFileOutput)
                self.session.sessionPreset = .hd4K3840x2160
                if let connection = movieFileOutput.connection(with: .video) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
                
                self.movieOutput = movieFileOutput
                
                DispatchQueue.main.async {
                    self.capture.isEnabled = true
                }
            }
            
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera, if available, otherwise default to a wide angle camera.
            
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                // If the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                do {
                    _ = try videoDeviceInput.device.lockForConfiguration()
                } catch {
                    print("error")
                }
                videoDeviceInput.device.focusMode = .continuousAutoFocus
                videoDeviceInput.device.unlockForConfiguration()
                self.videoDeviceInput = videoDeviceInput
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    private func startFlash() {
        let avDevice = self.videoDeviceInput.device

         // check if the device has torch
        if avDevice.hasFlash {
             // lock your device for configuration
             do {
                 _ = try avDevice.lockForConfiguration()
             } catch {
                 print("error")
             }

             // check if your torchMode is on or off. If on turns it off otherwise turns it on
            if avDevice.isTorchActive {
                avDevice.torchMode = AVCaptureDevice.TorchMode.off
                self.flash.setImage(UIImage(named:"flash_off"), for: .normal)
             } else {
                // sets the torch intensity to 100%
                do {
                    _ = try avDevice.setTorchModeOn(level: 0.5)
                } catch {
                    print("error")
                }
                self.flash.setImage(UIImage(named:"flash_on"), for: .normal)
             }
             // unlock your device
             avDevice.unlockForConfiguration()
        }
    }
    
    /**
     Starting recording consists of several functionalities:
     - First timer is created in Model
     - All signals are created and subscribed on
     - Finaly, timer is triggered and outout file is opened
     */
    private func startRecording() {
        _ = self.viewModel.inputs.createTimer()
        let videoPreviewLayerOrientation = self.preview.videoPreviewLayer.connection?.videoOrientation
        // Timer signal
        self.viewModel.outputs.labelTimerSignal
            .observeOn(MainScheduler.instance)
            .bind(to: self.timeLapsed.rx.text)
            .disposed(by: disposeBag)
        // Signal for starting and stoping recording
        self.viewModel.outputs.recordingSignal
            .subscribe(onNext: { status in
                if status {
                    self.sessionQueue.async {
                        if !self.movieOutput.isRecording {
                            if UIDevice.current.isMultitaskingSupported {
                                self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                            }
                            
                            // Update the orientation on the movie file output video connection before recording.
                            let movieFileOutputConnection = self.movieOutput.connection(with: .video)
                            movieFileOutputConnection?.videoOrientation = videoPreviewLayerOrientation!
                            
                            let availableVideoCodecTypes = self.movieOutput.availableVideoCodecTypes
                            
                            if availableVideoCodecTypes.contains(.hevc) {
                                self.movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                            }
                            
                            // Start recording video to a temporary file.
                            let outputFileName = NSUUID().uuidString
                            let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
                            self.movieOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
                        }
                    }
                } else {
                    self.capture.setImage(#imageLiteral(resourceName: "Capture"), for: [])
                    self.movieOutput.stopRecording()
        //                    self.saveFile()
                    return
                }
            }).disposed(by: self.disposeBag)
        // Signal for starting or stopping the flash
        self.viewModel.outputs.flashSignal
            .subscribe(onNext: { status in
                let avDevice = self.videoDeviceInput.device

                 // check if the device has torch
                if avDevice.hasFlash {
                     // lock your device for configuration
                     do {
                         _ = try avDevice.lockForConfiguration()
                     } catch {
                         print("error")
                     }

                     // check if your torchMode is on or off. If on turns it off otherwise turns it on
                    if !status {
                        avDevice.torchMode = AVCaptureDevice.TorchMode.off
                        self.flash.setImage(UIImage(named:"flash_off"), for: .normal)
                     } else {
                        // sets the torch intensity to 100%
                        do {
                            _ = try avDevice.setTorchModeOn(level: 0.5)
                        } catch {
                            print("error")
                        }
                        self.flash.setImage(UIImage(named:"flash_on"), for: .normal)
                     }
                     // unlock your device
                     avDevice.unlockForConfiguration()
                 }
            }).disposed(by: self.disposeBag)
        if self.movieOutput.isRecording {
            self.capture.setImage(#imageLiteral(resourceName: "CapturePressed"), for: [])
            self.viewModel.inputs.stopRecording()
        }
        else {
            self.capture.setImage(#imageLiteral(resourceName: "Capture"), for: [])
            self.viewModel.inputs.startRecording()
        }
    }
    
    private func saveFile() {
        let activityController = UIActivityViewController(activityItems: [self.movieOutput.outputFileURL as Any], applicationActivities: nil)
        self.present(activityController, animated: true, completion: nil)
    }
    
    func insert(viewModel: RecordingViewModelProtocol) {
        self.viewModel = viewModel
    }
    
    // MARK: Focus Methods
    @objc func tapToFocus(_ recognizer: UIGestureRecognizer) {
        print("Focusing...")
        if videoDeviceInput.device.isFocusPointOfInterestSupported {
            let point = recognizer.location(in: self.preview)
            let pointOfInterest = self.preview.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
            print("Focusing at: \(point)")
            focusAtPoint(point: pointOfInterest)
        }
    }
    
    private func focusAtPoint(point: CGPoint) {
        let device = videoDeviceInput.device
        // Make sure the device supports focus on POI and Auto Focus.
        if device.isFocusPointOfInterestSupported &&
            device.isFocusModeSupported(AVCaptureDevice.FocusMode.autoFocus) {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = AVCaptureDevice.FocusMode.autoFocus
                device.unlockForConfiguration()
            } catch {
                print("Error focusing on POI: \(error)")
            }
        }
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    /// - Tag: DidStartRecording
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Enable the Record button to let the user stop recording.
        DispatchQueue.main.async {
            self.capture.isEnabled = true
            self.capture.setImage(#imageLiteral(resourceName: "CapturePressed"), for: [])
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Enable the Record button to let the user stop recording.
        DispatchQueue.main.async {
            self.capture.isEnabled = true
            self.timeLapsed.text = "Starting recording"
            self.capture.setImage(#imageLiteral(resourceName: "Capture"), for: [])
        }
    }
}


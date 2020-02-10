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
    
    var preview: PreviewView!
    var capture: UIButton!
    let session = AVCaptureSession()
    private var isSessionRunning = false
    let movieOutput = AVCaptureMovieFileOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    
    let disposeBag = DisposeBag()
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var setupResult: SessionSetupResult = .success
    
    private var viewModel: RecordingViewModelProtocol!
    
    let timerSubject = Observable<Int>.interval(.milliseconds(1), scheduler: MainScheduler.instance).debug().publish()
    
    var labelUpdateSubscription: Disposable!
    
    var firstFlashStop: Disposable!
    var secondFlashStart: Disposable!
    var secondFlashStop: Disposable!
    
    var connection: Disposable?

    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let model = DataGatheringModel()
//        self.viewModel = RecordingViewModel(with: model)

        connection = nil
        
        labelUpdateSubscription = self.timerSubject.subscribe(onNext: { value in
            print(value)
        })
        
        firstFlashStop = self.viewModel.inputs.createFilteredObservableWith(condition: 3000)
            .subscribe(onNext: { _ in
                self.startFlash()
            })
        secondFlashStart = self.viewModel.inputs.createFilteredObservableWith(condition: 6000)
            .subscribe(onNext: { _ in
                self.startFlash()
            })
        secondFlashStop = self.viewModel.inputs.createFilteredObservableWith(condition: 6250)
            .subscribe(onNext: { _ in
                self.startFlash()
                self.stopRecording()
            })

        preview = PreviewView()
        preview.backgroundColor = UIColor.red
        self.view.addSubview(preview)
        preview.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
        preview.session = session
        
        capture = UIButton()
        capture.setImage(UIImage(named: "Capture"), for: .normal)
        
        self.view.addSubview(capture)
        capture.snp.makeConstraints { (make) in
            make.centerX.equalTo(self.view.snp.centerX)
            make.bottom.equalTo(self.view).inset(35)
        }
        self.capture.rx.tap
            .debug()
            .subscribe(onNext: { _ in
                self.startFlash()
                self.startRecording()
            })
            .disposed(by: disposeBag)
        
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    func startFlash() {
        let avDevice = videoDeviceInput.device

         // check if the device has torch
        if avDevice.hasFlash {
             // lock your device for configuration
             do {
                 _ = try avDevice.lockForConfiguration()
             } catch {
                 print("aaaa")
             }

             // check if your torchMode is on or off. If on turns it off otherwise turns it on
            if avDevice.isTorchActive {
                avDevice.torchMode = AVCaptureDevice.TorchMode.off
             } else {
                 // sets the torch intensity to 100%
                 do {
                    _ = try avDevice.setTorchModeOn(level: 1.0)
                 } catch {
                     print("bbb")
                 }
                self.capture.setImage(UIImage(named: "CapturePressed"), for: .normal)
             //    avDevice.setTorchModeOnWithLevel(1.0, error: nil)
             }
             // unlock your device
             avDevice.unlockForConfiguration()
         }
    }
    
    func startRecording() {
        print("start recording")
        self.connection = self.viewModel.inputs.connectToTimer()
    }
    
    func stopRecording() {
        self.labelUpdateSubscription?.dispose()
        self.firstFlashStop?.dispose()
        self.secondFlashStart?.dispose()
        self.secondFlashStop?.dispose()
        self.connection?.dispose()
        self.capture.setImage(UIImage(named: "Capture"), for: .normal)
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
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        /*
         Do not create an AVCaptureMovieFileOutput when setting up the session because
         Live Photo is not supported when AVCaptureMovieFileOutput is added to the session.
         */
        session.sessionPreset = .hd4K3840x2160
        
        // Add video input.
        do {
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
                DispatchQueue.main.async {
                    /*
                     Dispatch video streaming to the main queue because AVCaptureVideoPreviewLayer is the backing layer for PreviewView.
                     You can manipulate UIView only on the main thread.
                     Note: As an exception to the above rule, it's not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                     
                     Use the window scene's orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    var initialVideoOrientation: AVCaptureVideoOrientation = .landscapeLeft
                    if self.windowOrientation != .unknown {
                        if let videoOrientation = AVCaptureVideoOrientation(rawValue: self.windowOrientation.rawValue) {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    self.preview.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                }
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
    
    func insert(viewModel: RecordingViewModelProtocol) {
        self.viewModel = viewModel
    }

}


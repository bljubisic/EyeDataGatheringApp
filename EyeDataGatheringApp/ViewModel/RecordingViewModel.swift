//
//  RecordingViewModel.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 10.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

class RecordingViewModel: RecordingViewModelProtocol {
    var model: DataGatheringModelProtocol
    
    private var timer: ConnectableObservable<Int>?
    private var flashSubject: PublishSubject<Bool> = PublishSubject()
    private var recordingSubject: PublishSubject<Bool> = PublishSubject()
    private var labelTimerSubject: PublishSubject<String> = PublishSubject()
    private var labelUpdateSubscription: Disposable!
    
    private var firstFlashStart: Disposable!
    private var firstFlashStop: Disposable!
    private var secondFlashStart: Disposable!
    private var secondFlashStop: Disposable!
    private var stopVideo: Disposable!
    
    private var connection: Disposable?
    
    func createFilteredObservableWith(condition: Int) -> Observable<Int>? {
        guard let timer = self.timer else {
            return nil
        }
        return timer
            .filter { value -> Bool in
                return value == condition
        }
    }
    
    func createObservableWithoutCondition() -> Observable<Int>? {
        guard let timer = self.timer else {
            return nil
        }
        return timer.asObservable()
    }
    
    func connectToTimer() -> Disposable? {
        guard let timer = self.timer else {
            return nil
        }
        return timer.connect()
    }
    
    func store(file: EyeInfo) -> (Bool, Error?) {
        return self.model.inputs.storeAndEncrypt(file: file)
    }
    
    init(with model: DataGatheringModelProtocol) {
        self.model = model
    }
    
    func createTimer() -> Bool {
        self.timer = self.model.inputs.createTimer()
        return true
    }
    
}

extension RecordingViewModel: RecordingInputs {
    
    func startRecording() {
        print("start recording")
        _ = self.model.inputs.createTimer()
        connection = nil
        
        // Responsible for main timer in application
        
        labelUpdateSubscription = self.createObservableWithoutCondition()!
            .filter{ value -> Bool in
                return value % 1000 == 0
            }
            .map({ value -> String in
                return "sec: \(value / 1000)"
            })
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { value in
                self.labelTimerSubject.onNext(value)
            })
    
        // First flash should start after 5 seconds
        firstFlashStart = self.createFilteredObservableWith(condition: 5000)!
            .subscribe(onNext: { _ in
                self.flashSubject.onNext(true)
            })
        //first flash should stop after 3 seconds
        firstFlashStop = self.createFilteredObservableWith(condition: 8000)!
            .subscribe(onNext: { _ in
                self.flashSubject.onNext(false)
            })
        // second flash should start 3 seconds after first one
        secondFlashStart = self.createFilteredObservableWith(condition: 11000)!
            .subscribe(onNext: { _ in
                self.flashSubject.onNext(true)
            })
        
        // second flash lasts 0.25 seconds.
        secondFlashStop = self.createFilteredObservableWith(condition: 11250)!
            .subscribe(onNext: { _ in
                self.flashSubject.onNext(false)
            })
        
        // stop video after 2 seconds. Whole video is 13 second long
        stopVideo = self.createFilteredObservableWith(condition: 13250)!
            .subscribe(onNext: { _ in
                self.labelUpdateSubscription?.dispose()
                self.firstFlashStop?.dispose()
                self.secondFlashStart?.dispose()
                self.secondFlashStop?.dispose()
                self.connection?.dispose()
                self.recordingSubject.onNext(false)
            })
        self.recordingSubject.onNext(true)
        self.connection = self.connectToTimer()
    }
    
    var inputs: RecordingInputs {
        return self
    }
}

extension RecordingViewModel: RecordingOutputs {
    
    var flashSignal: Observable<Bool> {
        return self.flashSubject
    }
    
    var recordingSignal: Observable<Bool> {
        return self.recordingSubject
    }
    
    var outputs: RecordingOutputs {
        return self
    }
    
    var labelTimerSignal: Observable<String> {
        return self.labelTimerSubject
    }
    
}

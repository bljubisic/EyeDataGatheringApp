//
//  RecordingViewModelProtocol.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 10.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

protocol RecordingInputs {
    func createFilteredObservableWith(condition: Int) -> Observable<Int>?
    func createObservableWithoutCondition() -> Observable<Int>?
    func connectToTimer() -> Disposable?
    func createTimer() -> Bool
    func store(file: EyeInfo) -> (Bool, Error?)
    func startRecording() -> Void
    func stopRecording() -> Void
}

protocol RecordingOutputs {
    var model: DataGatheringModelProtocol { get }
    
    var flashSignal: Observable<Bool> { get }
    var recordingSignal: Observable<Bool> { get }
    var labelTimerSignal: Observable<String> { get }
}

protocol RecordingViewModelProtocol {
    var inputs: RecordingInputs { get }
    var outputs: RecordingOutputs { get }
}

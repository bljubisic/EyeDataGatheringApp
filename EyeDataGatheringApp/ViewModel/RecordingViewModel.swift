//
//  RecordingViewModel.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 10.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

class RecordingViewModel: RecordingViewModelProtocol, RecordingInputs, RecordingOutputs {
    var model: DataGatheringModelProtocol
    
    private var timer: ConnectableObservable<Int>?
    
    var inputs: RecordingInputs {
        return self
    }
    
    var outputs: RecordingOutputs {
        return self
    }
    
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

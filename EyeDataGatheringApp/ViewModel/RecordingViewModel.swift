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
    
    var inputs: RecordingInputs {
        return self
    }
    
    var outputs: RecordingOutputs {
        return self
    }
    
    func createFilteredObservableWith(condition: Int) -> Observable<Int> {
        return self.model.outputs.timer
            .filter { value -> Bool in
                return value == condition
        }
    }
    
    func createObservableWithoutCondition() -> Observable<Int> {
        return self.model.outputs.timer
    }
    
    func connectToTimer() -> Disposable {
        return self.model.inputs.connect()
    }
    
    func store(file: EyeInfo) -> (Bool, Error?) {
        return self.model.inputs.storeAndEncrypt(file: file)
    }
    
    init(with model: DataGatheringModelProtocol) {
        self.model = model
    }
    
}

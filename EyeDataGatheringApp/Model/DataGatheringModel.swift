//
//  DataGatheringModel.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 10.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift


class DataGatheringModel: DataGatheringModelProtocol, DataGatheringInputs, DataGatheringOutputs {
    /**
     Creating the Timer observable which push one event every miliseconds
     */
    func createTimer() -> ConnectableObservable<Int> {
        return Observable.interval(.milliseconds(1), scheduler: MainScheduler.instance).publish()
    }
    
    var inputs: DataGatheringInputs {
        return self
    }
    
    var outputs: DataGatheringOutputs {
        return self
    }
    
    func storeAndEncrypt(file: EyeInfo) -> (Bool, Error?) {
        return (true, nil)
    }
    
}

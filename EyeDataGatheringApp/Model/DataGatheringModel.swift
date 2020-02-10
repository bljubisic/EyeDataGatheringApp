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
    var inputs: DataGatheringInputs {
        return self
    }
    
    var outputs: DataGatheringOutputs {
        return self
    }
    
    func connect() -> Disposable {
        return self.timer.connect()
    }
    
    func storeAndEncrypt(file: EyeInfo) -> (Bool, Error?) {
        return (true, nil)
    }
    
    var timer: ConnectableObservable<Int>
    
    init() {
        timer = Observable.interval(.milliseconds(1), scheduler: MainScheduler.instance).publish()
    }
    
}

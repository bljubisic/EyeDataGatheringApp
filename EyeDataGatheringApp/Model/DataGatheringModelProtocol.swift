//
//  IDataGatheringModel.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 08.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

protocol DataGatheringInputs {
    func connect() -> Disposable
    func storeAndEncrypt(file: EyeInfo) -> (Bool, Error?)
}

protocol DataGatheringOutputs {
    var timer: ConnectableObservable<Int> { get }
}


protocol DataGatheringModelProtocol {
    var inputs: DataGatheringInputs { get }
    var outputs: DataGatheringOutputs { get }
}

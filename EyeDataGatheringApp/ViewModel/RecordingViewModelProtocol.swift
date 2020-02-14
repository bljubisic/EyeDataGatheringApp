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
}

protocol RecordingOutputs {
    var model: DataGatheringModelProtocol { get }
}

protocol RecordingViewModelProtocol {
    var inputs: RecordingInputs { get }
    var outputs: RecordingOutputs { get }
}

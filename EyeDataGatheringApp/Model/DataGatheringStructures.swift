//
//  DataGatheringStructures.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 08.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import Foundation

struct EyeInfo {
    let name: String
    let file: Data
    let createdAt: Date
    let updatedAt: Date
}

extension EyeInfo {
    init() {
        self.name = ""
        self.file = Data()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

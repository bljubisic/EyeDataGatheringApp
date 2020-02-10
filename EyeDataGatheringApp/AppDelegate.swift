//
//  AppDelegate.swift
//  EyeDataGatheringApp
//
//  Created by Bratislav Ljubisic on 08.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {


    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let model = DataGatheringModel()
        let recordingViewModel = RecordingViewModel(with: model)

        
        let viewController: ViewController = ViewController()
        viewController.insert(viewModel: recordingViewModel)
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        return true
    }


}


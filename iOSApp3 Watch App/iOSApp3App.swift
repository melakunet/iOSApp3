//
//  iOSApp3App.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - App Entry Point

@main
struct iOSApp3_Watch_AppApp: App {

    // MARK: - Shared managers

    @StateObject private var healthManager    = HealthManager()
    @StateObject private var locationManager  = LocationManager()
    @StateObject private var motivationManager = MotivationManager()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(locationManager)
                .environmentObject(motivationManager)
                .task {
                    await healthManager.requestAuthorization()
                }
        }
    }
}

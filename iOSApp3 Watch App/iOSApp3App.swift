//
//  iOSApp3App.swift
//  iOSApp3 Watch App
//
//  Purpose: App entry point for StepRecovery. Creates the shared
//           HealthManager and LocationManager instances and injects
//           them into the view hierarchy, then triggers HealthKit
//           authorization on first launch.
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - App Entry Point

@main
struct iOSApp3_Watch_AppApp: App {

    // MARK: - Shared managers

    /// Single source of truth for all HealthKit data.
    /// @StateObject ensures the manager lives as long as the app does.
    @StateObject private var healthManager = HealthManager()

    /// Handles one-shot GPS capture and reverse-geocoding.
    @StateObject private var locationManager = LocationManager()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject managers into the environment so any child view
                // can access them via @EnvironmentObject if needed later.
                .environmentObject(healthManager)
                .environmentObject(locationManager)
                // Request HealthKit authorization as soon as the root view appears.
                // Using .task so it runs asynchronously and doesn't block the UI.
                .task {
                    await healthManager.requestAuthorization()
                }
        }
    }
}

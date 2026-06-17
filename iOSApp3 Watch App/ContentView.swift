//
//  ContentView.swift
//  iOSApp3 Watch App
//
//  Purpose: Temporary root view for Phase 1.
//           Displays the app name and the current HealthKit
//           authorization status so we can confirm the permission
//           flow works on a real device or simulator.
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    // MARK: - Dependencies

    /// Injected from the environment by iOSApp3App.
    @EnvironmentObject var healthManager: HealthManager

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {

            // App name / title
            Text("StepRecovery")
                .font(.headline)
                .foregroundStyle(.primary)

            // HealthKit authorization status — useful during development
            // to confirm the permission sheet fired correctly.
            Text(healthManager.isAuthorized ? "HealthKit: Authorized" : "HealthKit: Not authorized")
                .font(.caption2)
                .foregroundStyle(healthManager.isAuthorized ? .green : .orange)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    // Provide a dummy HealthManager so the canvas doesn't need real HealthKit.
    ContentView()
        .environmentObject(HealthManager())
}

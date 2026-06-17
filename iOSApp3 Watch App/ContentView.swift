//
//  ContentView.swift
//  iOSApp3 Watch App
//
//  Purpose: Root view for StepRecovery. Shows the app logo, name,
//           and current HealthKit authorization status.
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

            // App logo from Assets.xcassets/steprecovery_sr_logo.imageset
            Image("steprecovery_sr_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)

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

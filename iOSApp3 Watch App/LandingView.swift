//
//  LandingView.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - LandingView

struct LandingView: View {

    // MARK: - Environment objects

    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var motivationManager: MotivationManager

    // MARK: - Navigation

    // Bound to ContentView so Get Started can jump straight to the Dashboard tab.
    @Binding var selectedTab: Int

    // MARK: - Local animation state

    @State private var isWalking = false

    // MARK: - Body

    var body: some View {
        // ZStack lets the motivational Capsule float above content without shifting other views.
        ZStack(alignment: .top) {

            VStack(spacing: 10) {

                // Oscillates between -4 and +4 pts to mimic a walking rhythm.
                Image(systemName: "figure.walk")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .offset(y: isWalking ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isWalking
                    )

                Text("StepRecovery")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("Track steps, burn calories,\nand recover smarter.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Get Started") {
                    withAnimation { selectedTab = 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .font(.caption)
                .fontWeight(.semibold)
            }
            .padding(.top, 20)
            .padding(.horizontal, 8)

            // MARK: Motivational pop-up

            if let message = motivationManager.currentMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue.opacity(0.85)))
                    .padding(.top, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            Image("steprecovery_sr_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .padding(.top, 6)
                .padding(.leading, 6)
        }

        // MARK: - Lifecycle

        .onAppear {
            isWalking = true
        }
        .onChange(of: healthManager.todaySteps) { _, newSteps in
            guard newSteps > 0 else { return }
            motivationManager.celebrate(steps: newSteps)
        }
    }
}

// MARK: - Previews

#Preview("Welcome screen") {
    let health = HealthManager()
    let motivation = MotivationManager()

    return LandingView(selectedTab: .constant(0))
        .environmentObject(health)
        .environmentObject(motivation)
}

#Preview("With pop-up visible") {
    let health = HealthManager()
    let motivation = MotivationManager()
    motivation.currentMessage = "Nice — every step counts! (2500 steps)"

    return LandingView(selectedTab: .constant(0))
        .environmentObject(health)
        .environmentObject(motivation)
}

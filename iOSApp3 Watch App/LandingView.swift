//
//  LandingView.swift
//  iOSApp3 Watch App
//
//  Purpose: Welcome screen shown on app launch. Introduces StepRecovery with
//           an animated walking figure, a brief tagline, and a Get Started
//           button that jumps straight to the Dashboard tab. Motivational
//           pop-ups still appear here whenever the step count updates.
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - LandingView

/// The welcome screen — the first tab the user sees when they open StepRecovery.
/// Shows the app name, a brief tagline, and a Get Started button that navigates
/// directly to the Dashboard. Motivational messages can pop in from the top
/// while the user lingers here as their step count updates throughout the day.
struct LandingView: View {

    // MARK: - Environment objects

    /// Provides live step count so motivational pop-ups fire on step updates.
    @EnvironmentObject var healthManager: HealthManager

    /// Controls the brief motivational pop-up that slides in from the top.
    @EnvironmentObject var motivationManager: MotivationManager

    // MARK: - Navigation

    /// Bound to ContentView's selectedTab — setting this to 1 jumps the user
    /// directly to the Dashboard tab when they tap Get Started.
    @Binding var selectedTab: Int

    // MARK: - Local animation state

    /// Toggled true on appear so the walking figure starts oscillating immediately.
    @State private var isWalking = false

    // MARK: - Body

    var body: some View {
        // ZStack lets the motivational Capsule float above the main content
        // without pushing any other views around.
        ZStack(alignment: .top) {

            // MARK: Main content stack
            VStack(spacing: 10) {

                // Walking figure bounce animation — the app's signature visual.
                // The offset oscillates between -4 and +4 pts, mimicking a
                // gentle step rhythm. repeatForever + autoreverses loops it endlessly.
                Image(systemName: "figure.walk")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .offset(y: isWalking ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isWalking
                    )

                // App name — establishes brand identity on the welcome screen.
                Text("StepRecovery")
                    .font(.headline)
                    .fontWeight(.bold)

                // One-line tagline describing the app's value proposition.
                Text("Track steps, burn calories,\nand recover smarter.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Get Started — jumps to the Dashboard tab so the user can
                // see their live metrics without manually swiping.
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
            // Only rendered when MotivationManager has a non-nil message.
            // The transition slides the Capsule in from the top edge and fades
            // it in; the reverse plays automatically when the view is removed.
            if let message = motivationManager.currentMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.85))
                    )
                    .padding(.top, 2)
                    // combined(with:) runs both transitions at the same time.
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // SR logo pinned to the top-left corner, rendered above all ZStack layers.
        // Adding the overlay here (not on TabView) guarantees it is always visible.
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
            // Start the walking-figure oscillation on first render.
            isWalking = true
        }
        // Fire a motivational pop-up whenever today's step count increases.
        .onChange(of: healthManager.todaySteps) { _, newSteps in
            // Guard against the initial 0-step publish so no pop-up fires at launch.
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
    // Pre-load a message so the Capsule pop-up is visible without waiting for steps.
    motivation.currentMessage = "Nice — every step counts! (2500 steps)"

    return LandingView(selectedTab: .constant(0))
        .environmentObject(health)
        .environmentObject(motivation)
}

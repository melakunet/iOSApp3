//
//  LandingView.swift
//  iOSApp3 Watch App
//
//  Purpose: Main landing screen shown on app launch. Displays today's calorie
//           burn with a count-up animation, a protein recovery target, an
//           animated walking figure, and brief motivational pop-ups when
//           the step count updates.
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - LandingView

/// The primary screen the user sees when they open StepRecovery.
/// Reads live HealthKit data from HealthManager and shows motivational
/// messages managed by MotivationManager.
struct LandingView: View {

    // MARK: - Environment objects

    /// Provides live step count, calorie burn, and flights climbed.
    @EnvironmentObject var healthManager: HealthManager

    /// Controls the brief motivational pop-up that slides in from the top.
    @EnvironmentObject var motivationManager: MotivationManager

    // MARK: - Local animation state

    /// Toggled true on appear so the walking figure starts oscillating immediately.
    @State private var isWalking = false

    /// Animated copy of todayActiveCalories — counts up from 0 on first appear
    /// so the user watches their burn total reveal itself.
    @State private var displayedCalories: Double = 0

    // MARK: - Computed properties

    /// Protein recovery target in grams.
    /// Delegated to RecoveryCalculator so this number stays in sync with
    /// the Recovery Coach tab — both screens show the same recommendation.
    private var proteinTarget: Int {
        RecoveryCalculator.proteinGrams(forCalories: healthManager.todayActiveCalories)
    }

    // MARK: - Body

    var body: some View {
        // ZStack lets the motivational Capsule float above the main content
        // without pushing any other views around.
        ZStack(alignment: .top) {

            // MARK: Main content stack
            VStack(spacing: 8) {

                // Walking figure.
                // The offset oscillates between -4 and +4 pts, mimicking a
                // gentle bounce. repeatForever + autoreverses loops it endlessly.
                Image(systemName: "figure.walk")
                    .font(.system(size: 34))
                    .foregroundStyle(.green)
                    .offset(y: isWalking ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isWalking
                    )

                // Calorie burn headline.
                // numericText() makes the digits roll like a counter as
                // displayedCalories animates from 0 to the real value.
                Text("You burned ~\(Int(displayedCalories)) cal today — keep it up!")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 1.5), value: displayedCalories)

                // Protein target supporting line.
                // Secondary color keeps it subordinate to the calorie headline.
                Text("Aim for ~\(proteinTarget)g protein to recover")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            // Top padding reserves space so main text never hides under the pop-up.
            .padding(.top, 24)
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

        // MARK: - Lifecycle

        .onAppear {
            // Start the walking-figure oscillation on first render.
            isWalking = true

            // Reveal today's calorie total with a 1.5-second count-up.
            withAnimation(.easeInOut(duration: 1.5)) {
                displayedCalories = healthManager.todayActiveCalories
            }
        }
        // Keep the calorie display current as HealthKit delivers live updates.
        .onChange(of: healthManager.todayActiveCalories) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                displayedCalories = newValue
            }
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

#Preview("Normal state") {
    let health = HealthManager()
    health.todayActiveCalories = 312
    health.todaySteps = 4_820
    let motivation = MotivationManager()

    return LandingView()
        .environmentObject(health)
        .environmentObject(motivation)
}

#Preview("With pop-up visible") {
    let health = HealthManager()
    health.todayActiveCalories = 200
    health.todaySteps = 2_500
    let motivation = MotivationManager()
    // Pre-load a message so the Capsule pop-up is visible without waiting for steps.
    motivation.currentMessage = "Nice — every step counts! (2500 steps)"

    return LandingView()
        .environmentObject(health)
        .environmentObject(motivation)
}

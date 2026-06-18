//
//  RecoveryCoachView.swift
//  iOSApp3 Watch App
//
//  Purpose: Guides the user through post-walk recovery. Shows progress toward
//           the daily step goal, and — once the goal is reached — displays
//           estimated calories burned, a protein target range, and a short
//           list of recovery tips. Fires a haptic and a local notification
//           the first time the goal is crossed in a session.
//
//  Created by Etefworkie Melaku
//

import SwiftUI
import UserNotifications  // For local notification scheduling
import WatchKit           // For WKInterfaceDevice haptic feedback

// MARK: - RecoveryCoachView

/// The recovery-coaching screen, shown as the third tab in ContentView.
/// All calculations are delegated to RecoveryCalculator so this file
/// focuses purely on presentation.
struct RecoveryCoachView: View {

    // MARK: - Environment

    /// Provides live step count used to compute progress and recovery metrics.
    @EnvironmentObject var healthManager: HealthManager

    // MARK: - Constants

    /// Daily step goal — must match the value used in DashboardView.
    private let goalSteps = 12_000

    /// Short post-walk recovery tips shown when the goal is reached.
    private let tips: [(icon: String, text: String)] = [
        ("drop.fill",        "Drink 500 ml water"),
        ("figure.cooldown",  "Stretch calves 2 min each"),
        ("figure.flexibility","Stretch hamstrings 30 s")
    ]

    // MARK: - State

    /// Guards the haptic + notification so they fire only once per session,
    /// even if the step count continues to increase past the goal.
    @State private var goalCelebrated = false

    // MARK: - Computed properties

    /// Today's step count from HealthKit.
    private var steps: Int { healthManager.todaySteps }

    /// Progress fraction 0...1 toward the daily goal.
    private var progress: Double {
        RecoveryCalculator.progress(steps: steps, goal: goalSteps)
    }

    /// Estimated calories burned today using the MET formula.
    private var calories: Double {
        RecoveryCalculator.caloriesBurned(steps: steps)
    }

    /// Lower bound of the protein recommendation window (15–25 g).
    private var proteinLow: Int {
        RecoveryCalculator.proteinGrams(forCalories: calories)
    }

    /// Upper bound: add a 5 g buffer above the base recommendation.
    private var proteinHigh: Int { proteinLow + 5 }

    /// Steps remaining before the goal is reached. Never negative.
    private var stepsRemaining: Int { max(0, goalSteps - steps) }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // Top spacer reserves room so the pinned logo doesn't overlap content.
                Spacer().frame(height: 18)

                if progress < 1.0 {
                    // MARK: Under goal — show progress bar + steps remaining
                    VStack(spacing: 8) {

                        Text("Recovery Guide")
                            .font(.caption)
                            .fontWeight(.semibold)

                        // Animated progress bar; tint shifts toward green as it fills.
                        ProgressView(value: progress)
                            .tint(progress > 0.75 ? .green : .blue)
                            .animation(.easeInOut(duration: 0.5), value: progress)

                        Text("\(stepsRemaining.formatted()) steps to unlock your recovery guide")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                } else {
                    // MARK: Goal reached — show full recovery guide
                    VStack(spacing: 8) {

                        Text("Goal reached! 🎉")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)

                        // Calorie summary from the MET calculator.
                        Text("You burned ~\(Int(calories)) calories")
                            .font(.caption2)

                        // Protein range: base recommendation ± 5 g buffer.
                        Text("Consume \(proteinLow)g–\(proteinHigh)g protein to recover")
                            .font(.caption2)
                            .multilineTextAlignment(.center)

                        Divider()

                        // Recovery tips list.
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(tips, id: \.text) { tip in
                                Label(tip.text, systemImage: tip.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        // SR logo pinned to the top-left corner above the scroll content.
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
            // Ask for notification permission when the user first visits this tab.
            // The system shows the prompt only once; subsequent calls are no-ops.
            requestNotificationAuthorization()

            // Handle the case where the app is launched after the goal was already
            // reached — we don't fire an additional haptic on appear.
        }
        // Watch for step-count changes so we can react the moment the goal is crossed.
        .onChange(of: healthManager.todaySteps) { _, newSteps in
            let newProgress = RecoveryCalculator.progress(steps: newSteps, goal: goalSteps)

            // Only celebrate once per session — goalCelebrated prevents re-firing
            // if steps keep climbing after the goal threshold.
            if newProgress >= 1.0 && !goalCelebrated {
                goalCelebrated = true

                // Strong success haptic so the user feels the achievement.
                WKInterfaceDevice.current().play(.success)

                // Schedule a local notification to appear on the watch face.
                scheduleGoalNotification()
            }
        }
    }

    // MARK: - Private helpers

    /// Requests authorization to show alerts and play sounds for local notifications.
    /// Safe to call repeatedly — the OS only shows the permission dialog once.
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Notification auth error: \(error.localizedDescription)")
            }
        }
    }

    /// Schedules a one-shot local notification that fires 1 second after the
    /// goal is reached, giving the user positive reinforcement on the watch face.
    private func scheduleGoalNotification() {
        // Build the notification payload.
        let content = UNMutableNotificationContent()
        content.title = "Goal reached!"
        content.body  = "Time to recover 💪"
        content.sound = .default

        // Trigger after 1 second so it arrives almost immediately.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // A fixed identifier means a second notification replaces the first
        // rather than stacking, which avoids duplicate banners.
        let request = UNNotificationRequest(
            identifier: "stepGoalReached",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Previews

#Preview("Under goal – 8,000 steps") {
    let health = HealthManager()
    health.todaySteps = 8_000
    health.todayActiveCalories = 280

    return RecoveryCoachView()
        .environmentObject(health)
}

#Preview("Over goal – 13,000 steps") {
    let health = HealthManager()
    health.todaySteps = 13_000
    health.todayActiveCalories = 460

    return RecoveryCoachView()
        .environmentObject(health)
}

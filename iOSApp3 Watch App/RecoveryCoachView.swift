//
//  RecoveryCoachView.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import SwiftUI
import UserNotifications
import WatchKit

// MARK: - RecoveryCoachView

struct RecoveryCoachView: View {

    // MARK: - Environment

    @EnvironmentObject var healthManager: HealthManager

    // MARK: - Constants

    private let goalSteps = 12_000

    // UserDefaults key storing "yyyy-MM-dd" of the last celebration so it resets at midnight, not on every launch.
    private let celebratedKey = "lastGoalCelebrationDate"

    private let tips: [(icon: String, text: String)] = [
        ("drop.fill",        "Drink 500 ml water"),
        ("figure.cooldown",  "Stretch calves 2 min each"),
        ("figure.flexibility","Stretch hamstrings 30 s")
    ]

    // MARK: - Computed properties

    private var steps: Int { healthManager.todaySteps }

    private var progress: Double {
        RecoveryCalculator.progress(steps: steps, goal: goalSteps)
    }

    private var calories: Double {
        RecoveryCalculator.caloriesBurned(steps: steps)
    }

    private var proteinLow: Int {
        RecoveryCalculator.proteinGrams(forCalories: calories)
    }

    // 5 g buffer above the base recommendation
    private var proteinHigh: Int { proteinLow + 5 }

    private var stepsRemaining: Int { max(0, goalSteps - steps) }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                Spacer().frame(height: 18)

                if progress < 1.0 {

                    VStack(spacing: 8) {

                        Text("Recovery Guide")
                            .font(.caption)
                            .fontWeight(.semibold)

                        ProgressView(value: progress)
                            .tint(progress > 0.75 ? .green : .blue)
                            .animation(.easeInOut(duration: 0.5), value: progress)

                        Text("\(stepsRemaining.formatted()) steps to unlock your recovery guide")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                } else {

                    VStack(spacing: 8) {

                        Text("Goal reached! 🎉")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)

                        Text("You burned ~\(Int(calories)) calories")
                            .font(.caption2)

                        Text("Consume \(proteinLow)g–\(proteinHigh)g protein to recover")
                            .font(.caption2)
                            .multilineTextAlignment(.center)

                        Divider()

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
            requestNotificationAuthorization()
        }
        .onChange(of: healthManager.todaySteps) { _, newSteps in
            let newProgress = RecoveryCalculator.progress(steps: newSteps, goal: goalSteps)
            guard newProgress >= 1.0 else { return }

            // Only celebrate once per calendar day, not once per launch.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            guard UserDefaults.standard.string(forKey: celebratedKey) != today else { return }

            UserDefaults.standard.set(today, forKey: celebratedKey)
            WKInterfaceDevice.current().play(.success)
            scheduleGoalNotification()
        }
    }

    // MARK: - Private helpers

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { print("Notification auth error: \(error.localizedDescription)") }
        }
    }

    private func scheduleGoalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Goal reached!"
        content.body  = "Time to recover 💪"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Fixed identifier so a second notification replaces the first rather than stacking.
        let request = UNNotificationRequest(
            identifier: "stepGoalReached",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule notification: \(error.localizedDescription)") }
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

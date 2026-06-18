//
//  ContentView.swift
//  iOSApp3 Watch App
//
//  Purpose: Root navigation container for StepRecovery. A vertically-paged
//           TabView lets the user scroll between the Landing motivational
//           screen and the Dashboard metrics screen. All managers are
//           injected from the App level so both tabs share live data.
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - ContentView

/// Root view that hosts the four main tabs.
///
/// Navigation structure:
///   Tab 1 (top)    → LandingView       – walking animation, calorie summary, pop-ups
///   Tab 2          → DashboardView     – step hero, flights, calories, Start Walk
///   Tab 3          → RecoveryCoachView – progress bar, protein guide, recovery tips
///   Tab 4 (bottom) → HistoryView       – 7-day step and calorie totals, impact estimate
///
/// .verticalPage stacks tabs top-to-bottom so the user scrolls or spins the
/// Digital Crown to move between screens — the standard watchOS 10+ pattern.
struct ContentView: View {

    // MARK: - Body

    var body: some View {
        // Each direct child of TabView becomes one swipeable page.
        // EnvironmentObject values injected by iOSApp3App flow down automatically
        // to all tabs without re-passing them here.
        TabView {

            // Tab 1 — motivational landing with animated walking figure.
            LandingView()

            // Tab 2 — live fitness metrics and walk-start capture.
            DashboardView()

            // Tab 3 — recovery coach: goal progress, protein range, tips, notification.
            RecoveryCoachView()

            // Tab 4 — history: real 7-day HealthKit totals and impact estimate.
            HistoryView()
        }
        // .verticalPage: pages scroll vertically (Digital Crown or swipe up/down).
        // Introduced in watchOS 10; the standard interaction on Apple Watch.
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Preview

#Preview {
    let health = HealthManager()
    health.todayActiveCalories = 200
    health.todaySteps = 3_000
    let location = LocationManager()
    let motivation = MotivationManager()

    return ContentView()
        .environmentObject(health)
        .environmentObject(location)
        .environmentObject(motivation)
}

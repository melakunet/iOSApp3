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
///   Tab 0 (top)    → LandingView       – welcome screen, Get Started button
///   Tab 1          → DashboardView     – step hero, flights, calories, Start Walk
///   Tab 2          → RecoveryCoachView – progress bar, protein guide, recovery tips
///   Tab 3 (bottom) → HistoryView       – 7-day step and calorie totals, impact estimate
///
/// selectedTab is passed as a @Binding to LandingView so the Get Started button
/// can jump the user straight to the Dashboard without manual swiping.
struct ContentView: View {

    // MARK: - Tab selection

    /// Tracks the active tab index. LandingView's Get Started button sets this to 1
    /// (Dashboard) so the user lands on live metrics immediately after the welcome screen.
    @State private var selectedTab = 0

    // MARK: - Body

    var body: some View {
        // Each direct child of TabView becomes one swipeable page.
        // EnvironmentObject values injected by iOSApp3App flow down automatically
        // to all tabs without re-passing them here.
        TabView(selection: $selectedTab) {

            // Tab 0 — welcome screen with animated walking figure and Get Started button.
            LandingView(selectedTab: $selectedTab)
                .tag(0)

            // Tab 1 — live fitness metrics and walk-start capture.
            DashboardView()
                .tag(1)

            // Tab 2 — recovery coach: goal progress, protein range, tips, notification.
            RecoveryCoachView()
                .tag(2)

            // Tab 3 — history: real 7-day HealthKit totals and impact estimate.
            HistoryView()
                .tag(3)
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

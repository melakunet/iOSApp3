//
//  ContentView.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    // MARK: - Tab selection

    // Passed as a Binding to LandingView so Get Started can jump to tab 1 programmatically.
    @State private var selectedTab = 0

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            LandingView(selectedTab: $selectedTab)
                .tag(0)

            DashboardView()
                .tag(1)

            RecoveryCoachView()
                .tag(2)

            HistoryView()
                .tag(3)
        }
        // .verticalPage: watchOS 10+ standard; pages scroll with Digital Crown or swipe.
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

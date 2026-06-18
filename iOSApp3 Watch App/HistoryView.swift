//
//  HistoryView.swift
//  iOSApp3 Watch App
//
//  Purpose: Shows a 7-day fitness summary fetched live from HealthKit, plus an
//           estimated caloric impact in pounds using the 3,500 kcal ≈ 1 lb rule.
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - HistoryView

/// The history screen, reachable as the fourth tab in ContentView.
/// Calls HealthManager.weeklyTotals() once on appear and displays the results
/// in two sections: raw totals and an estimated impact figure.
struct HistoryView: View {

    // MARK: - Dependencies

    @EnvironmentObject var healthManager: HealthManager

    // MARK: - State

    /// Seven-day step total loaded from HealthKit.
    @State private var weeklySteps: Int

    /// Seven-day active-energy total (kcal) loaded from HealthKit.
    @State private var weeklyCalories: Double

    /// True while the async fetch is in progress; shows a spinner.
    @State private var isLoading: Bool

    // MARK: - Initializer

    /// Default init starts in loading state (weeklyTotals() fetches real data).
    /// Pass mock values to skip the async call — used by Xcode Previews so the
    /// canvas shows realistic-looking data without needing a real device.
    init(mockSteps: Int = 0, mockCalories: Double = 0) {
        let hasMock = mockSteps > 0 || mockCalories > 0
        _weeklySteps    = State(initialValue: mockSteps)
        _weeklyCalories = State(initialValue: mockCalories)
        // If mock data was provided, skip loading spinner — results are already there.
        _isLoading      = State(initialValue: !hasMock)
        _useMockData    = State(initialValue: hasMock)
    }

    // Guards the .task so mock previews don't overwrite pre-loaded values.
    @State private var useMockData: Bool

    // MARK: - Computed properties

    /// Rule: 3,500 kcal of active energy ≈ 1 lb of fat mass.
    /// This is a rough physiological estimate — not scale weight.
    private var estimatedPounds: Double { weeklyCalories / 3_500.0 }

    /// True when both totals are still zero after loading completed.
    private var hasNoData: Bool { weeklySteps == 0 && weeklyCalories == 0 }

    // MARK: - Body

    var body: some View {
        List {

            // MARK: This Week section
            Section("This Week") {

                if isLoading {
                    // Spinner shown while the async HealthKit query is in flight.
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if hasNoData {
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    // Steps row
                    HStack {
                        Label("Steps", systemImage: "figure.walk")
                            .font(.caption2)
                        Spacer()
                        Text(weeklySteps.formatted())
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }

                    // Active calories row
                    HStack {
                        Label("Calories", systemImage: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Spacer()
                        Text("\(Int(weeklyCalories)) kcal")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
            }

            // MARK: Estimated Impact section
            Section("Estimated Impact") {

                if isLoading {
                    // Keep this section quiet while data is loading.
                    EmptyView()
                } else if hasNoData {
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        // One decimal place gives useful precision without false accuracy.
                        Text("~\(estimatedPounds, specifier: "%.1f") lbs active energy")
                            .font(.caption2)
                            .fontWeight(.semibold)

                        // Explain the calculation so the user understands the estimate.
                        // ~3,500 kcal of energy deficit ≈ 1 lb of fat — rough physiology rule.
                        Text("Rough estimate: ~3,500 kcal active energy ≈ 1 lb. Not scale weight.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        // SR logo pinned to the top-left corner above the list content.
        .overlay(alignment: .topLeading) {
            Image("steprecovery_sr_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .padding(.top, 6)
                .padding(.leading, 6)
        }

        // MARK: - Lifecycle

        .task {
            // Skip the live HealthKit fetch if this view was created with mock data.
            guard !useMockData else { return }

            // weeklyTotals() runs HKStatisticsCollectionQuery and suspends until
            // HealthKit delivers the 7-day aggregation — no blocking the main thread.
            let totals = await healthManager.weeklyTotals()
            weeklySteps    = totals.steps
            weeklyCalories = totals.activeCalories
            isLoading      = false
        }
    }
}

// MARK: - Previews

#Preview("With 7-day data") {
    // Pre-load realistic totals so the canvas shows the non-empty state.
    HistoryView(mockSteps: 42_150, mockCalories: 1_820)
        .environmentObject(HealthManager())
}

#Preview("No data yet") {
    // Default init → both totals zero → "No data yet" rows shown.
    HistoryView()
        .environmentObject(HealthManager())
}

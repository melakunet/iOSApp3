//
//  HistoryView.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - HistoryView

struct HistoryView: View {

    // MARK: - Dependencies

    @EnvironmentObject var healthManager: HealthManager

    // MARK: - State

    @State private var weeklySteps: Int
    @State private var weeklyCalories: Double
    @State private var isLoading: Bool

    // MARK: - Initializer

    // Pass mock values to skip the async fetch in Xcode Previews.
    init(mockSteps: Int = 0, mockCalories: Double = 0) {
        let hasMock = mockSteps > 0 || mockCalories > 0
        _weeklySteps    = State(initialValue: mockSteps)
        _weeklyCalories = State(initialValue: mockCalories)
        _isLoading      = State(initialValue: !hasMock)
        _useMockData    = State(initialValue: hasMock)
    }

    @State private var useMockData: Bool

    // MARK: - Computed properties

    // 3,500 kcal ≈ 1 lb of active energy (rough physiology rule, not scale weight).
    private var estimatedPounds: Double { weeklyCalories / 3_500.0 }

    private var hasNoData: Bool { weeklySteps == 0 && weeklyCalories == 0 }

    // MARK: - Body

    var body: some View {
        List {

            Section("This Week") {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if hasNoData {
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Label("Steps", systemImage: "figure.walk").font(.caption2)
                        Spacer()
                        Text(weeklySteps.formatted()).font(.caption2).fontWeight(.semibold)
                    }

                    HStack {
                        Label("Calories", systemImage: "flame.fill")
                            .font(.caption2).foregroundStyle(.red)
                        Spacer()
                        Text("\(Int(weeklyCalories)) kcal").font(.caption2).fontWeight(.semibold)
                    }
                }
            }

            Section("Estimated Impact") {
                if isLoading {
                    EmptyView()
                } else if hasNoData {
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("~\(estimatedPounds, specifier: "%.1f") lbs active energy")
                            .font(.caption2)
                            .fontWeight(.semibold)

                        Text("Rough estimate: ~3,500 kcal active energy ≈ 1 lb. Not scale weight.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
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

        .task {
            guard !useMockData else { return }
            let totals = await healthManager.weeklyTotals()
            weeklySteps    = totals.steps
            weeklyCalories = totals.activeCalories
            isLoading      = false
        }
    }
}

// MARK: - Previews

#Preview("With 7-day data") {
    HistoryView(mockSteps: 42_150, mockCalories: 1_820)
        .environmentObject(HealthManager())
}

#Preview("No data yet") {
    HistoryView()
        .environmentObject(HealthManager())
}

//
//  DashboardView.swift
//  iOSApp3 Watch App
//
//  Purpose: Fitness summary screen showing today's steps, flights, and active
//           calories. Lets the user capture their walk's starting location and
//           persists the last session detail across app relaunches via UserDefaults.
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - DashboardView

/// The metrics screen, reachable by swiping down from the Landing tab.
/// Reads live HealthKit data from HealthManager and GPS data from LocationManager.
struct DashboardView: View {

    // MARK: - Environment objects

    /// Provides live step count, flights climbed, and active calories.
    @EnvironmentObject var healthManager: HealthManager

    /// Handles one-shot location capture for the walk's starting point.
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - Constants

    /// Daily step goal displayed below the hero number.
    /// Hard-coded for now; a settings screen can expose this to the user later.
    private let stepGoal = 12_000

    /// UserDefaults key for persisting the last session "place – time" string.
    private let lastSessionKey = "lastSession"

    // MARK: - Session state

    /// Wall-clock time when the user tapped "Start Walk" this session.
    /// Nil before any walk is started.
    @State private var sessionStart: Date? = nil

    /// True while the async location-capture Task is in progress.
    /// Used to disable the button and show "Locating…" feedback.
    @State private var isCapturing = false

    // MARK: - Persisted state

    /// Last saved session string, loaded from UserDefaults on appear.
    /// Format: "City, Region – 2:34 PM". Nil if no session has ever been saved.
    @State private var lastSession: String? = nil

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 10) {

                // Top spacer reserves room so the pinned logo doesn't overlap the hero number.
                Spacer().frame(height: 18)

                // MARK: Hero step count
                // Large rounded-design number for fast glanceability on the small
                // watch face. numericText() makes the digit roll when it changes.
                VStack(spacing: 2) {
                    Text("\(healthManager.todaySteps)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: healthManager.todaySteps)

                    // Goal caption gives context to the raw number.
                    Text("/ \(stepGoal.formatted()) goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // MARK: Flights + Calories row
                // Two supporting metrics share one row so neither takes too much
                // vertical space on the small watch screen.
                HStack(spacing: 16) {

                    // Flights climbed
                    HStack(spacing: 4) {
                        Image(systemName: "figure.stairs")
                            .foregroundStyle(.orange)
                        Text("\(healthManager.todayFlights)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    // Active calories — whole numbers are precise enough here.
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.red)
                        Text("\(Int(healthManager.todayActiveCalories)) cal")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                Divider()

                // MARK: Start Walk button
                // Tapping captures the start time locally and then triggers the
                // async location fetch. The button is disabled while locating
                // so the user can't kick off a second capture by accident.
                Button {
                    sessionStart = Date()   // record the wall-clock start time
                    isCapturing = true
                    Task {
                        await locationManager.captureOrigin()
                        isCapturing = false
                    }
                } label: {
                    Label(
                        isCapturing ? "Locating…" : "Start Walk",
                        systemImage: "figure.walk.circle.fill"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isCapturing)

                // MARK: Current session origin
                // Only appears after startPlaceDescription is filled in this session.
                // Text(_:style:) with .time shows "2:34 PM" and ticks live —
                // useful for the user to see elapsed time from their walk start.
                if !locationManager.startPlaceDescription.isEmpty,
                   let start = sessionStart {
                    VStack(spacing: 2) {
                        Text(locationManager.startPlaceDescription)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text(start, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }

                // MARK: Last session (UserDefaults)
                // Shown every time the view appears, even after the app restarts,
                // because the string is written to the persistent UserDefaults store.
                if let last = lastSession {
                    Text("Last walk: \(last)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        // SR logo pinned to the top-left corner above the scroll content.
        // Placed on the ScrollView itself so it never scrolls away.
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
            // Read the persisted session string on every appearance.
            // Returns nil if the key has never been written (first launch).
            lastSession = UserDefaults.standard.string(forKey: lastSessionKey)
        }
        // Watch for a successful location result so we can persist the session.
        .onChange(of: locationManager.startPlaceDescription) { _, newPlace in
            // Ignore error strings and empty values — only save a real place.
            guard !newPlace.isEmpty,
                  !newPlace.hasPrefix("Location"),
                  let start = sessionStart else { return }

            // Build a short "City, Region – 2:34 PM" string for persistence.
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let sessionString = "\(newPlace) – \(formatter.string(from: start))"

            // Update the in-session display immediately so the user sees it.
            lastSession = sessionString

            // Persist to UserDefaults so the string survives app restarts.
            // UserDefaults.standard is the app's own sandboxed key-value store;
            // data written here remains until the app is deleted.
            UserDefaults.standard.set(sessionString, forKey: lastSessionKey)
        }
    }
}

// MARK: - Previews

#Preview("Dashboard – live data") {
    let health = HealthManager()
    health.todaySteps = 7_243
    health.todayFlights = 5
    health.todayActiveCalories = 287
    let location = LocationManager()

    return DashboardView()
        .environmentObject(health)
        .environmentObject(location)
}

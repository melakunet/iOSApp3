//
//  DashboardView.swift
//  iOSApp3 Watch App
//
//  Purpose: Fitness summary screen showing today's steps, flights, and active
//           calories. The Start Walk button always records a session — it writes
//           the start time immediately, then appends a place name if location
//           becomes available. Works fully with or without location permission.
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

    /// Handles optional one-shot location capture for the walk's starting point.
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - Constants

    /// Daily step goal displayed below the hero number.
    private let stepGoal = 12_000

    /// UserDefaults key for persisting the most recent session string.
    private let lastSessionKey = "lastSession"

    // MARK: - Session state

    /// The time the user tapped "Start Walk" this session. Used when the place
    /// arrives asynchronously so the full string can be rebuilt with the same time.
    @State private var sessionTime: Date? = nil

    /// True while the async location-capture Task is in progress.
    /// Used to disable the button and show "Locating…" feedback.
    @State private var isCapturing = false

    /// The current session display string, updated in real time.
    /// Format: "Walk started at 9:48 AM" or "Walk started at 9:48 AM – Toronto, ON".
    /// Nil before any session is started this app launch.
    @State private var currentSessionString: String? = nil

    // MARK: - Persisted state

    /// Most recent session string from UserDefaults. Shown when no session
    /// is active this launch so returning users see their last walk.
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

                    Text("/ \(stepGoal.formatted()) goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // MARK: Flights + Calories row
                HStack(spacing: 16) {

                    HStack(spacing: 4) {
                        Image(systemName: "figure.stairs")
                            .foregroundStyle(.orange)
                        Text("\(healthManager.todayFlights)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

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
                // Always works regardless of location permission.
                // The session string is recorded immediately on tap; the place
                // name is appended asynchronously if location becomes available.
                Button {
                    startSession()
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

                // MARK: Session display
                // Shows the active session string the moment the button is tapped.
                // Updates in place when the place name arrives asynchronously.
                // Falls back to the last persisted session when no session is active.
                if let session = currentSessionString ?? lastSession {
                    VStack(spacing: 3) {
                        Text(session)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)

                        // Tiny hint shown only when location is explicitly denied
                        // so the user understands why no place is attached.
                        if locationManager.authorizationStatus == .denied
                            || locationManager.authorizationStatus == .restricted {
                            Text("Location off")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.opacity)
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
            // Load the most recent persisted session so returning users always
            // see their last walk, even across app relaunches.
            lastSession = UserDefaults.standard.string(forKey: lastSessionKey)
        }
        // When the place arrives asynchronously (after geocoding or after the
        // user grants permission mid-session), rebuild the session string with
        // the place appended and persist the updated version.
        .onChange(of: locationManager.startPlaceDescription) { _, newPlace in
            guard let place = newPlace, let time = sessionTime else { return }
            let updated = buildSessionString(time: time, place: place)
            currentSessionString = updated
            persist(session: updated)
        }
    }

    // MARK: - Private helpers

    /// Called on every "Start Walk" tap.
    /// Records the start time immediately, persists a time-only session string,
    /// then fires the async location task in the background.
    private func startSession() {
        let now = Date()
        sessionTime = now
        isCapturing = true

        // Persist a time-only string right away so the user always gets feedback,
        // regardless of whether location is available.
        let initial = buildSessionString(time: now, place: nil)
        currentSessionString = initial
        persist(session: initial)

        Task {
            // captureOrigin() always returns cleanly — it never blocks the session.
            // If it gets a place, the onChange(of: startPlaceDescription) above
            // will update currentSessionString to the full "time – place" format.
            await locationManager.captureOrigin()
            isCapturing = false
        }
    }

    /// Builds the session display string.
    ///   • Without a place: "Walk started at 9:48 AM"
    ///   • With a place:    "Walk started at 9:48 AM – Toronto, ON"
    private func buildSessionString(time: Date, place: String?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = "Walk started at \(formatter.string(from: time))"
        if let place {
            return "\(timeString) – \(place)"
        }
        return timeString
    }

    /// Writes the session string to UserDefaults so it survives app restarts.
    private func persist(session: String) {
        lastSession = session
        UserDefaults.standard.set(session, forKey: lastSessionKey)
    }
}

// MARK: - Previews

#Preview("Dashboard – no location") {
    let health = HealthManager()
    health.todaySteps = 7_243
    health.todayFlights = 5
    health.todayActiveCalories = 287
    let location = LocationManager()

    return DashboardView()
        .environmentObject(health)
        .environmentObject(location)
}

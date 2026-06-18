//
//  DashboardView.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {

    // MARK: - Environment objects

    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - Constants

    private let stepGoal = 12_000
    private let lastSessionKey = "lastSession"

    // MARK: - Session state

    // Stored so the place name can be appended asynchronously with the same time.
    @State private var sessionTime: Date? = nil
    @State private var isCapturing = false
    @State private var currentSessionString: String? = nil

    // MARK: - Persisted state

    @State private var lastSession: String? = nil

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 10) {

                Spacer().frame(height: 18)

                // MARK: Hero step count

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

                if let session = currentSessionString ?? lastSession {
                    VStack(spacing: 3) {
                        Text(session)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)

                        // Shown only when location is explicitly off so the user understands why there's no place name.
                        if locationManager.authorizationStatus == .denied
                            || locationManager.authorizationStatus == .restricted {
                            Text("Location off")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.opacity)
                }

                // MARK: Debug step simulator

                #if DEBUG
                Divider()

                Button {
                    healthManager.addDebugSteps(1_000)
                } label: {
                    Label("+1,000 Steps (Debug)", systemImage: "plus.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                #endif
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
            lastSession = UserDefaults.standard.string(forKey: lastSessionKey)
        }
        .onChange(of: locationManager.startPlaceDescription) { _, newPlace in
            guard let place = newPlace, let time = sessionTime else { return }
            let updated = buildSessionString(time: time, place: place)
            currentSessionString = updated
            persist(session: updated)
        }
    }

    // MARK: - Private helpers

    private func startSession() {
        let now = Date()
        sessionTime = now
        isCapturing = true

        let initial = buildSessionString(time: now, place: nil)
        currentSessionString = initial
        persist(session: initial)

        Task {
            await locationManager.captureOrigin()
            isCapturing = false
        }
    }

    private func buildSessionString(time: Date, place: String?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = "Walk started at \(formatter.string(from: time))"
        if let place { return "\(timeString) – \(place)" }
        return timeString
    }

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

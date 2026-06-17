//
//  HealthManager.swift
//  iOSApp3 Watch App
//
//  Purpose: Manages all HealthKit data access for StepRecovery.
//           Requests authorization, fetches today's step count,
//           flights climbed, and active calories, and keeps those
//           values up-to-date via observer queries.
//
//  Created by Etefworkie Melaku
//

import Combine       // Required for ObservableObject, @Published, and ObjectWillChangePublisher
import Foundation
import HealthKit

// MARK: - Private helpers (file-scope, nonisolated)

/// Builds a predicate for HealthKit samples from midnight today to right now.
/// Defined at file scope (not inside the @MainActor class) so it can safely
/// be called from HealthKit background-thread callbacks without crossing
/// the actor boundary.
private func makeTodayPredicate() -> NSPredicate {
    // startOfDay gives us midnight in the device's local time zone.
    let startOfDay = Calendar.current.startOfDay(for: Date())
    return HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: Date(),
        options: .strictStartDate
    )
}

// MARK: - HealthManager

/// Central class for reading HealthKit data.
/// @MainActor ensures every @Published update happens on the main thread,
/// which is required for driving SwiftUI views safely.
@MainActor
final class HealthManager: ObservableObject {

    // MARK: - Shared HealthKit store

    /// One HKHealthStore per app is the Apple-recommended pattern.
    private let store = HKHealthStore()

    // MARK: - Published properties

    /// Total step count for today (midnight → now). Stays 0 if no data.
    @Published var todaySteps: Int = 0

    /// Total flights climbed for today.
    @Published var todayFlights: Int = 0

    /// Total active-energy burned today, in kilocalories.
    @Published var todayActiveCalories: Double = 0.0

    /// True once the user has granted at least read permission.
    @Published var isAuthorized: Bool = false

    // MARK: - HealthKit types we need

    /// The three quantity types this app reads.
    private let readTypes: Set<HKQuantityType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.activeEnergyBurned)
    ]

    // MARK: - Authorization

    /// Asks the user for HealthKit read permissions.
    /// Must be called before any query is started.
    /// Safe to call more than once — HealthKit shows the sheet only once.
    func requestAuthorization() async {
        // HealthKit is not available on all devices (e.g. iPod touch).
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device.")
            return
        }

        do {
            // Request read-only access; we never write health data.
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            // Start live queries as soon as we have permission.
            startTodayObservers()
        } catch {
            // Authorization errors are non-fatal — values simply stay at 0.
            print("HealthKit authorization error: \(error.localizedDescription)")
        }
    }

    // MARK: - Observers

    /// Sets up three pairs of queries (one statistics query + one observer query
    /// per data type) so the published values update automatically all day.
    func startTodayObservers() {
        setupObserver(for: HKQuantityType(.stepCount),          unit: .count())
        setupObserver(for: HKQuantityType(.flightsClimbed),     unit: .count())
        setupObserver(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie())
    }

    // MARK: - Private helpers

    /// Creates one statistics query (immediate fetch) and one observer query
    /// (fires whenever new data arrives) for the given quantity type.
    ///
    /// HKQuery callbacks run on a HealthKit background thread, not the main actor.
    /// We capture `store` as a local constant before the closure (HKHealthStore
    /// is Sendable) and use the file-scope `makeTodayPredicate()` function so
    /// no actor-isolated state is accessed from the background thread.
    private func setupObserver(for type: HKQuantityType, unit: HKUnit) {

        // Capture the store locally so it is accessible inside the non-isolated closure.
        let capturedStore = store

        // --- 1. Immediate statistics query (gives us today's current total) ---
        let statsQuery = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: makeTodayPredicate(),
            options: .cumulativeSum           // steps, flights, and calories are cumulative
        ) { [weak self] _, statistics, error in
            if let error {
                print("Stats query error (\(type.identifier)): \(error.localizedDescription)")
                return
            }
            let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
            // Hop to the main actor to mutate @Published properties safely.
            Task { @MainActor [weak self] in
                self?.update(type: type, value: value)
            }
        }
        capturedStore.execute(statsQuery)

        // --- 2. Observer query (wakes us up when new samples are saved) ---
        let observerQuery = HKObserverQuery(
            sampleType: type,
            predicate: nil          // nil = watch all samples of this type
        ) { [weak self] _, completionHandler, error in
            if let error {
                print("Observer query error (\(type.identifier)): \(error.localizedDescription)")
                completionHandler()
                return
            }
            // Re-run a fresh statistics query to get the updated total.
            // makeTodayPredicate() is file-scope and nonisolated — safe to call here.
            let refreshQuery = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: makeTodayPredicate(),
                options: .cumulativeSum
            ) { [weak self] _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                Task { @MainActor [weak self] in
                    self?.update(type: type, value: value)
                }
                // Tell HealthKit we finished processing this update.
                completionHandler()
            }
            capturedStore.execute(refreshQuery)
        }
        capturedStore.execute(observerQuery)
    }

    /// Routes a fresh value to the correct @Published property.
    /// Called only from `Task { @MainActor in }` blocks above.
    private func update(type: HKQuantityType, value: Double) {
        switch type {
        case HKQuantityType(.stepCount):
            todaySteps = Int(value)
        case HKQuantityType(.flightsClimbed):
            todayFlights = Int(value)
        case HKQuantityType(.activeEnergyBurned):
            todayActiveCalories = value
        default:
            break
        }
    }
}

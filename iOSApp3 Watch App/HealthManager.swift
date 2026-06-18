//
//  HealthManager.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import Combine       // ObservableObject, @Published
import Foundation
import HealthKit

// MARK: - Private helpers

// File-scope so HK background callbacks can call this without crossing the actor boundary.
private func makeTodayPredicate() -> NSPredicate {
    let startOfDay = Calendar.current.startOfDay(for: Date())
    return HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: Date(),
        options: .strictStartDate
    )
}

// MARK: - HealthManager

@MainActor
final class HealthManager: ObservableObject {

    // MARK: - Store

    private let store = HKHealthStore()

    // MARK: - Private backing stores

    // Keeps raw HK steps separate so the DEBUG bonus survives observer refreshes.
    private var realSteps: Int = 0

    // MARK: - Published properties

    @Published var todaySteps: Int = 0
    @Published var todayFlights: Int = 0
    @Published var todayActiveCalories: Double = 0.0

    // MARK: - HealthKit types

    private let readTypes: Set<HKQuantityType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.activeEnergyBurned)
    ]

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            startTodayObservers()
        } catch {
            print("HealthKit authorization error: \(error.localizedDescription)")
        }
    }

    // MARK: - Debug step simulator

    #if DEBUG

    @Published var debugStepBonus: Int = 0

    func addDebugSteps(_ count: Int = 1_000) {
        debugStepBonus += count
        todaySteps = realSteps + debugStepBonus
        // Keep calories consistent with the simulated total.
        todayActiveCalories = RecoveryCalculator.caloriesBurned(steps: todaySteps)
    }

    #endif

    // MARK: - Observers

    func startTodayObservers() {
        setupObserver(for: HKQuantityType(.stepCount),          unit: .count())
        setupObserver(for: HKQuantityType(.flightsClimbed),     unit: .count())
        setupObserver(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie())
    }

    // MARK: - Private helpers

    private func setupObserver(for type: HKQuantityType, unit: HKUnit) {

        // Captured locally so the closure doesn't cross the @MainActor boundary.
        let capturedStore = store

        let statsQuery = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: makeTodayPredicate(),
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            if let error { print("Stats query error (\(type.identifier)): \(error.localizedDescription)"); return }
            let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
            Task { @MainActor [weak self] in self?.update(type: type, value: value) }
        }
        capturedStore.execute(statsQuery)

        let observerQuery = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                print("Observer query error (\(type.identifier)): \(error.localizedDescription)")
                completionHandler()
                return
            }
            let refreshQuery = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: makeTodayPredicate(),
                options: .cumulativeSum
            ) { [weak self] _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                Task { @MainActor [weak self] in self?.update(type: type, value: value) }
                completionHandler()
            }
            capturedStore.execute(refreshQuery)
        }
        capturedStore.execute(observerQuery)
    }

    private func update(type: HKQuantityType, value: Double) {
        switch type {
        case HKQuantityType(.stepCount):
            realSteps = Int(value)
            todaySteps = realSteps
            #if DEBUG
            todaySteps += debugStepBonus
            if debugStepBonus > 0 {
                todayActiveCalories = RecoveryCalculator.caloriesBurned(steps: todaySteps)
            }
            #endif
        case HKQuantityType(.flightsClimbed):
            todayFlights = Int(value)
        case HKQuantityType(.activeEnergyBurned):
            #if DEBUG
            // Skip while a debug bonus is active; addDebugSteps() already set calories.
            if debugStepBonus == 0 { todayActiveCalories = value }
            #else
            todayActiveCalories = value
            #endif
        default:
            break
        }
    }

    // MARK: - Weekly history

    func weeklyTotals() async -> (steps: Int, activeCalories: Double) {
        guard HKHealthStore.isHealthDataAvailable() else { return (0, 0.0) }

        let calendar     = Calendar.current
        let now          = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) else {
            return (0, 0.0)
        }

        var interval = DateComponents()
        interval.day = 1

        let predicate = HKQuery.predicateForSamples(
            withStart: sevenDaysAgo,
            end: now,
            options: .strictStartDate
        )

        let steps = await fetchWeeklySum(
            for: HKQuantityType(.stepCount),
            interval: interval, anchor: startOfToday,
            predicate: predicate, unit: .count()
        )
        let calories = await fetchWeeklySum(
            for: HKQuantityType(.activeEnergyBurned),
            interval: interval, anchor: startOfToday,
            predicate: predicate, unit: .kilocalorie()
        )

        return (Int(steps), calories)
    }

    private func fetchWeeklySum(
        for type:      HKQuantityType,
        interval:      DateComponents,
        anchor:        Date,
        predicate:     NSPredicate,
        unit:          HKUnit
    ) async -> Double {

        let capturedStore = store

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType:            type,
                quantitySamplePredicate: predicate,
                options:                 .cumulativeSum,
                anchorDate:              anchor,
                intervalComponents:      interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    print("Weekly sum error (\(type.identifier)): \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                let total = results?.statistics().reduce(into: 0.0) { acc, stats in
                    acc += stats.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                } ?? 0.0
                continuation.resume(returning: total)
            }

            capturedStore.execute(query)
        }
    }
}

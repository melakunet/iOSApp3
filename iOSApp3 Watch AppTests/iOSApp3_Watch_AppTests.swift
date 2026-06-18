//
//  iOSApp3_Watch_AppTests.swift
//  iOSApp3 Watch AppTests
//
//  Created by Etefworkie Melaku on 2026-06-17.
//

import Testing
@testable import iOSApp3_Watch_App

struct iOSApp3_Watch_AppTests {

    // MARK: - RecoveryCalculator

    @Test func caloriesBurnedMidDay() {
        // 3.5 MET × 70 kg × (6000/6000 h) = 245 kcal
        #expect(RecoveryCalculator.caloriesBurned(steps: 6_000) == 245.0)
    }

    @Test func proteinClampsToMinimum() {
        // 50 kcal / 25 = 2 g → clamped to 15
        #expect(RecoveryCalculator.proteinGrams(forCalories: 50) == 15)
    }

    @Test func proteinClampsToMaximum() {
        // 1000 kcal / 25 = 40 g → clamped to 25
        #expect(RecoveryCalculator.proteinGrams(forCalories: 1_000) == 25)
    }

    @Test func proteinMidRange() {
        // 500 kcal / 25 = 20 g → in range, no clamping
        #expect(RecoveryCalculator.proteinGrams(forCalories: 500) == 20)
    }

    @Test func progressHalfway() {
        #expect(RecoveryCalculator.progress(steps: 6_000, goal: 12_000) == 0.5)
    }

    @Test func progressZero() {
        #expect(RecoveryCalculator.progress(steps: 0, goal: 12_000) == 0.0)
    }

    @Test func progressCapsAtOne() {
        // 15,000 steps exceeds 12,000 goal — must cap at 1.0
        #expect(RecoveryCalculator.progress(steps: 15_000, goal: 12_000) == 1.0)
    }
}

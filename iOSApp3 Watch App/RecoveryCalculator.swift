//
//  RecoveryCalculator.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import Foundation

// MARK: - RecoveryCalculator

/// Pure static functions — no state, no side effects. Easy to unit-test.
struct RecoveryCalculator {

    // MARK: - Calorie Estimation

    // MET 3.5 = moderate walking; 12,000 steps ≈ 2 h, so hours = steps / 6,000.
    static func caloriesBurned(steps: Int, weightKg: Double = 70) -> Double {
        let met   = 3.5
        let hours = Double(steps) / 6_000.0
        return met * weightKg * hours
    }

    // MARK: - Protein Recommendation

    // 1 g per 25 kcal, clamped to the 15–25 g sports-nutrition window.
    static func proteinGrams(forCalories calories: Double) -> Int {
        let raw = (calories / 25.0).rounded()
        return Int(min(25, max(15, raw)))
    }

    // MARK: - Step Progress

    // Caps at 1.0 so the progress bar never overflows.
    static func progress(steps: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(steps) / Double(goal))
    }
}

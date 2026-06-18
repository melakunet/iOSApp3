//
//  RecoveryCalculator.swift
//  iOSApp3 Watch App
//
//  Purpose: Pure static calculations for recovery metrics — no UI, no HealthKit.
//           Keeping the math in one place makes it easy to test, read, and reuse
//           across multiple views without duplicating formulas.
//
//  Created by Etefworkie Melaku
//

import Foundation

// MARK: - RecoveryCalculator

/// Collection of static helper functions used across the app's recovery screens.
/// All functions are stateless and side-effect-free: given the same input they
/// always return the same output, which makes them trivial to unit-test.
struct RecoveryCalculator {

    // MARK: - Calorie Estimation

    /// Estimates kilocalories burned from a step count using the MET formula.
    ///
    /// Formula: Calories = MET × weight_kg × hours
    ///   - MET 3.5 is the standard metabolic equivalent for moderate-pace walking
    ///     (source: Ainsworth et al. Compendium of Physical Activities).
    ///   - 12,000 steps ≈ 2 hours of walking, so hours = steps / 6,000.
    ///   - Context: 3,500 kcal ≈ 1 lb of body fat — so this estimate lets the
    ///     user understand the caloric significance of their daily walk.
    ///
    /// - Parameters:
    ///   - steps: Today's total step count.
    ///   - weightKg: User's body weight in kilograms. Defaults to 70 kg.
    /// - Returns: Estimated kilocalories burned (kcal).
    static func caloriesBurned(steps: Int, weightKg: Double = 70) -> Double {
        let met  = 3.5                       // MET for moderate walking
        let hours = Double(steps) / 6_000.0 // 12,000 steps ≈ 2 h, so 1 step ≈ 1/6,000 h
        return met * weightKg * hours
    }

    // MARK: - Protein Recommendation

    /// Returns a post-workout protein target in grams, scaled to calories burned
    /// and clamped to the 15–25 g post-workout recommendation window.
    ///
    /// Rule: Sports nutrition guidelines recommend 15–25 g of high-quality
    /// protein after endurance exercise to support muscle repair. We scale
    /// linearly (1 g per 25 kcal burned) so lighter sessions get a lower target.
    ///
    /// - Parameter calories: Estimated kilocalories burned.
    /// - Returns: Recommended protein intake in grams, always in 15...25.
    static func proteinGrams(forCalories calories: Double) -> Int {
        // 1 g protein per 25 kcal; round to nearest whole gram.
        let raw = (calories / 25.0).rounded()
        // Clamp: never go below the minimum or above the maximum guideline.
        return Int(min(25, max(15, raw)))
    }

    // MARK: - Step Progress

    /// Returns progress toward the step goal as a fraction in 0...1.
    ///
    /// - Parameters:
    ///   - steps: Today's step count.
    ///   - goal: The target step count (e.g. 12,000).
    /// - Returns: 0.0 (no steps) through 1.0 (goal reached or exceeded).
    static func progress(steps: Int, goal: Int) -> Double {
        // Guard prevents division by zero if goal is somehow zero.
        guard goal > 0 else { return 0 }
        // min(1.0, ...) caps the fraction at 1.0 even if steps exceed the goal.
        return min(1.0, Double(steps) / Double(goal))
    }
}

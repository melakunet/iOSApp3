//
//  MotivationManager.swift
//  iOSApp3 Watch App
//
//  Purpose: Manages short motivational messages that appear briefly when the
//           user's step count updates. Messages pop up, fire a haptic, and
//           auto-dismiss so they encourage without cluttering the watch screen.
//
//  Created by Etefworkie Melaku
//

import Combine    // Required for ObservableObject and @Published
import Foundation
import SwiftUI    // Required for withAnimation
import WatchKit   // Required for WKInterfaceDevice haptic feedback

// MARK: - MotivationManager

/// Picks and displays one short motivational message at a time.
/// @MainActor ensures every @Published mutation happens on the main thread,
/// which is required for driving SwiftUI views safely.
@MainActor
final class MotivationManager: ObservableObject {

    // MARK: - Published properties

    /// The message currently shown in the pop-up. Nil means no pop-up is visible.
    @Published var currentMessage: String? = nil

    // MARK: - Private constants

    /// Pool of short encouragements randomly selected on each step update.
    private let messages: [String] = [
        "Nice — every step counts!",
        "Keep going!",
        "That's one more than before",
        "You're moving — love it",
        "Small steps, big wins"
    ]

    // MARK: - Public API

    /// Selects a random encouragement, optionally embedding the step count,
    /// displays it in the pop-up, fires a light haptic, then auto-clears
    /// the message after 2.5 seconds.
    ///
    /// We clear the message on a timer because the pop-up is designed to
    /// appear briefly and disappear — leaving it permanently would compete
    /// with the main content on the small watch screen.
    func celebrate(steps: Int) {
        // Bail out if the message pool is somehow empty (defensive guard).
        guard let base = messages.randomElement() else { return }

        // Include the step count so the message feels personally relevant.
        let message = steps > 0 ? "\(base) (\(steps) steps)" : base

        // Animate the Capsule sliding down from the top of the screen.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = message
        }

        // A light tap lets the user feel the encouragement as well as read it.
        WKInterfaceDevice.current().play(.click)

        // After 2.5 s, animate the pop-up back out.
        // Task suspends without blocking the main thread so the UI stays smooth.
        // Without this clear, the message would stay on screen indefinitely.
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.4)) {
                currentMessage = nil
            }
        }
    }
}

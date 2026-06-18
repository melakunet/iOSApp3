//
//  MotivationManager.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import Combine    // ObservableObject, @Published
import Foundation
import SwiftUI    // withAnimation
import WatchKit   // WKInterfaceDevice haptic

// MARK: - MotivationManager

@MainActor
final class MotivationManager: ObservableObject {

    // MARK: - Published properties

    /// Nil means no pop-up is visible.
    @Published var currentMessage: String? = nil

    // MARK: - Private constants

    private let messages: [String] = [
        "Nice — every step counts!",
        "Keep going!",
        "That's one more than before",
        "You're moving — love it",
        "Small steps, big wins"
    ]

    // MARK: - Public API

    func celebrate(steps: Int) {
        guard let base = messages.randomElement() else { return }
        let message = steps > 0 ? "\(base) (\(steps) steps)" : base

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = message
        }

        WKInterfaceDevice.current().play(.click)

        // Auto-dismiss after 2.5 s so the pop-up doesn't linger on the small screen.
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.4)) {
                currentMessage = nil
            }
        }
    }
}

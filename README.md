# StepRecovery (iOSApp3)
*Trios College — iOS Development (MWD3A), Assignment 5*

A standalone watchOS app that reads my HealthKit activity (steps, flights climbed, active calories), optionally logs where a walk started using CoreLocation, and gives me tailored recovery advice — calorie estimate and protein target — when I hit my 12,000-step goal.

## Features (from Week 5 lesson)
- `ObservableObject` / `@Published` / `@StateObject` for three shared managers (Health, Location, Motivation)
- `UserDefaults` persistence for walk sessions and per-day goal celebration
- Local `UserNotifications` + WatchKit haptics on goal completion
- `async` / `Task` for HealthKit queries and location capture
- `withAnimation` for the walking figure bounce and motivational pop-ups
- `TabView` with `.verticalPage` style across four screens

## Screens
- **Landing** — animated walking figure, app tagline, motivational pop-ups on step changes
- **Dashboard** — live steps / flights / calories hero + Start Walk button that logs location
- **Recovery Coach** — animated progress bar; unlocks calorie estimate and protein target at goal
- **History** — real 7-day HealthKit totals and estimated caloric impact

## How to run / test
- Open in Xcode, select the **iOSApp3 Watch App** scheme, and run on an Apple Watch simulator (watchOS 10+).
- The simulator has no health data — tap the **+1,000 Steps** debug button on the Dashboard (debug builds only) to simulate steps and see the calorie count-up, motivation pop-ups, and Recovery Coach goal screen unlock.
- On a real Apple Watch the app reads live HealthKit data automatically.

## Author
Etefworkie Melaku

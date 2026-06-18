//
//  LocationManager.swift
//  iOSApp3 Watch App
//
//  Purpose: Optionally captures a GPS fix at the start of a recovery walk
//           and reverse-geocodes it into a human-readable place name
//           (e.g. "Toronto, ON"). Location is never required — captureOrigin()
//           always returns cleanly, and startPlaceDescription stays nil if the
//           user denies access or the fix fails. The session is always recorded.
//
//  Created by Etefworkie Melaku
//

import Combine       // Required for ObservableObject and @Published
import Foundation
import CoreLocation
import MapKit        // Required for MKReverseGeocodingRequest (replaces CLGeocoder)

// MARK: - LocationManager

/// Handles optional one-shot location capture and reverse geocoding.
/// @MainActor ensures all @Published mutations happen on the main thread.
/// CLLocationManager delivers delegate callbacks on the main thread by default,
/// so accessing the async continuation from delegate methods is safe.
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Core Location

    private let locationManager = CLLocationManager()

    // MARK: - Published properties

    /// Reflects the user's current location permission for this app.
    /// Updated live from locationManagerDidChangeAuthorization so views
    /// can react immediately when the user changes the setting.
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// True when the user has granted When In Use (or Always) authorization.
    /// Views read this to decide whether to show a "Location off" hint.
    @Published var locationAvailable: Bool = false

    /// City and region of the origin fix once geocoding succeeds, e.g. "Toronto, ON".
    /// Stays nil if location is off, denied, or the geocoding step fails.
    /// DashboardView watches this and appends it to the session string when it arrives.
    @Published var startPlaceDescription: String? = nil

    /// Raw coordinate of the origin fix. Nil until a valid fix is obtained.
    @Published var startCoordinate: CLLocationCoordinate2D? = nil

    // MARK: - Private state

    /// Bridges the CLLocationManager delegate callback to async/await.
    /// We hold at most one continuation at a time — the one-shot pattern.
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // MARK: - Initializer

    override init() {
        super.init()
        // Assign the delegate after super.init() so self is fully initialised.
        locationManager.delegate = self
        // Best accuracy for a single origin fix; battery impact is brief.
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Sync published properties with whatever status the OS already holds
        // so views have the correct state before the first delegate callback.
        let status = locationManager.authorizationStatus
        authorizationStatus = status
        locationAvailable = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    // MARK: - Public API

    /// Tries to capture a GPS fix and geocode it into startPlaceDescription.
    ///
    /// This function ALWAYS returns cleanly — it never blocks a session:
    ///   • .notDetermined   → asks for permission; delegate will retry if granted.
    ///   • .authorized*     → fetches a fix; leaves startPlaceDescription nil on failure.
    ///   • .denied/.restricted → returns immediately; place stays nil.
    ///
    /// The place description is reset at the start of every call so stale data
    /// from a previous session is never shown.
    func captureOrigin() async {
        // Clear any place from a previous session before starting a new fix.
        startPlaceDescription = nil
        startCoordinate = nil

        switch locationManager.authorizationStatus {

        case .notDetermined:
            // Show the system permission prompt. The session is already being
            // recorded by DashboardView with time only. If the user taps Allow,
            // locationManagerDidChangeAuthorization calls fetchAndGeocode() to
            // fill in the place after the fact.
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            // Permission is granted — request a one-shot fix and geocode it.
            // fetchAndGeocode() handles all errors; it never crashes or hangs.
            await fetchAndGeocode()

        default:
            // Denied or restricted — silently do nothing.
            // DashboardView is already recording the session with time only.
            break
        }
    }

    // MARK: - Private helpers

    /// Requests one GPS fix and reverse-geocodes the coordinate into
    /// startPlaceDescription. Leaves it nil on any error — never crashes.
    ///
    /// Uses MKReverseGeocodingRequest — the watchOS 26+ replacement for the
    /// deprecated CLGeocoder — bridged to async/await via CheckedContinuation.
    private func fetchAndGeocode() async {
        do {
            // Suspend until the CLLocationManager delegate delivers a fix.
            // requestLocation() triggers exactly one update, then stops.
            let location = try await withCheckedThrowingContinuation { continuation in
                locationContinuation = continuation
                locationManager.requestLocation()
            }

            startCoordinate = location.coordinate

            // MKReverseGeocodingRequest replaces the deprecated CLGeocoder.
            // The failable init returns nil only for an invalid coordinate.
            guard let request = MKReverseGeocodingRequest(location: location) else {
                // Invalid coordinate — leave place nil so the session stays time-only.
                return
            }

            // Bridge the completion-handler API to async/await so the calling
            // code remains linear and easy to read.
            let mapItems: [MKMapItem]? = await withCheckedContinuation { continuation in
                request.getMapItems { items, error in
                    if let error {
                        print("Reverse geocoding error: \(error.localizedDescription)")
                    }
                    // Resume with whatever arrived; nil on error → place stays nil.
                    continuation.resume(returning: items)
                }
            }

            // addressRepresentations replaces the deprecated MKPlacemark.placemark on watchOS 26+.
            // cityWithContext(.automatic) returns "City, Region" style automatically.
            // If geocoding returned nothing, startPlaceDescription simply stays nil.
            if let representations = mapItems?.first?.addressRepresentations {
                startPlaceDescription = representations.cityWithContext(.automatic)
                    ?? representations.cityName
            }

        } catch {
            // Location hardware error or timeout — leave place nil, never crash.
            print("LocationManager error: \(error.localizedDescription)")
        }
    }
}

// MARK: - CLLocationManagerDelegate

// @preconcurrency tells Swift that CLLocationManagerDelegate predates strict
// concurrency, so the conformance to this nonisolated Objective-C protocol from
// a @MainActor class is intentional and safe (CLLocationManager delivers its
// callbacks on the main thread by default).
extension LocationManager: @preconcurrency CLLocationManagerDelegate {

    /// Called whenever the user's location permission for this app changes.
    /// Updates authorizationStatus and locationAvailable so views react in real time.
    /// If access was just granted (after a .notDetermined tap), fetches a fix now
    /// so the place can be appended to any session already in progress.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status
        locationAvailable = (status == .authorizedWhenInUse || status == .authorizedAlways)

        if locationAvailable {
            // Permission was just granted — kick off the fix so the place can
            // be appended to the session string DashboardView already started.
            Task { await fetchAndGeocode() }
        }
        // Denied or restricted: locationAvailable = false, place stays nil — no crash.
    }

    /// Delivers the one-shot GPS fix to the waiting async continuation.
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil  // nil prevents a double-resume
    }

    /// Delivers a location error to the waiting async continuation.
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil  // nil prevents a double-resume
    }
}

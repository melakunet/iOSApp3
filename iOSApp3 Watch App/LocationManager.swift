//
//  LocationManager.swift
//  iOSApp3 Watch App
//
//  Purpose: Captures a single GPS fix at the start of a recovery walk
//           and reverse-geocodes it into a human-readable place name
//           (e.g. "Toronto, ON") so the user can see where they began.
//
//  Created by Etefworkie Melaku
//

import Combine       // Required for ObservableObject and @Published
import Foundation
import CoreLocation
import MapKit        // Required for MKReverseGeocodingRequest (replaces CLGeocoder)

// MARK: - LocationManager

/// Handles one-shot location capture and reverse geocoding.
/// @MainActor ensures all @Published mutations happen on the main thread.
/// CLLocationManager delivers delegate callbacks on the main thread by default,
/// so accessing the async continuation from delegate methods is safe.
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Core Location

    private let locationManager = CLLocationManager()

    // MARK: - Published properties

    /// Short description of the origin location, e.g. "Toronto, ON".
    /// Empty string until captureOrigin() succeeds.
    @Published var startPlaceDescription: String = ""

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
    }

    // MARK: - Public API

    /// Requests When In Use authorization (if not already granted), then
    /// takes a single location fix and reverse-geocodes it.
    /// Call this when the user taps "Start Walk".
    func captureOrigin() async {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Return early to avoid a race where requestLocation() fires before
            // the OS grants permission and immediately fails with an error.
            // locationManagerDidChangeAuthorization will call fetchAndGeocode()
            // once the user responds to the prompt.
            return
        }

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            startPlaceDescription = "Location access denied"
            return
        }

        await fetchAndGeocode()
    }

    // MARK: - Private helpers

    /// Requests one GPS fix and reverse-geocodes the coordinate into a
    /// short human-readable string (e.g. "Toronto, ON").
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
                startPlaceDescription = "Location unavailable"
                return
            }

            // Bridge the completion-handler API to async/await so the calling
            // code remains linear and easy to read.
            let mapItems: [MKMapItem]? = await withCheckedContinuation { continuation in
                request.getMapItems { items, error in
                    if let error {
                        print("Reverse geocoding error: \(error.localizedDescription)")
                    }
                    // Resume with whatever arrived; nil on error → fallback below.
                    continuation.resume(returning: items)
                }
            }

            // addressRepresentations replaces the deprecated MKPlacemark.placemark on watchOS 26+.
            // cityWithContext(.automatic) returns a "City, Region" style string automatically
            // (e.g. "Toronto, ON"), handling disambiguation without manual string building.
            if let representations = mapItems?.first?.addressRepresentations {
                startPlaceDescription = representations.cityWithContext(.automatic)
                    ?? representations.cityName
                    ?? "Unknown location"
            } else {
                startPlaceDescription = "Unknown location"
            }

        } catch {
            // Location or geocoding failed — show a safe fallback, never crash.
            print("LocationManager error: \(error.localizedDescription)")
            startPlaceDescription = "Location unavailable"
        }
    }
}

// MARK: - CLLocationManagerDelegate

// @preconcurrency tells Swift that CLLocationManagerDelegate predates strict
// concurrency, so the conformance to this nonisolated Objective-C protocol from
// a @MainActor class is intentional and safe (CLLocationManager delivers its
// callbacks on the main thread by default).
extension LocationManager: @preconcurrency CLLocationManagerDelegate {

    /// Called when the user responds to the permission prompt.
    /// If access was just granted, kick off the actual location fix.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { await fetchAndGeocode() }
        } else if status == .denied || status == .restricted {
            startPlaceDescription = "Location access denied"
        }
        // .notDetermined: the sheet is still visible — nothing to do yet.
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

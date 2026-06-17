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

import Combine
import Foundation
import CoreLocation

// MARK: - LocationManager

/// Handles one-shot location capture and reverse geocoding.
/// @MainActor ensures all @Published mutations happen on the main thread.
/// Uses CLLocationManagerDelegate callbacks bridged to async/await via a
/// CheckedContinuation so callers can simply use `await captureOrigin()`.
/// CLLocationManager delivers delegate callbacks on the main thread by default,
/// so accessing the continuation from delegate methods is safe.
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Core Location objects

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // MARK: - Published properties

    /// Short description of the origin location, e.g. "Toronto, ON".
    /// Empty string until captureOrigin() succeeds.
    @Published var startPlaceDescription: String = ""

    /// Raw coordinate of the origin fix. Nil until a fix is obtained.
    @Published var startCoordinate: CLLocationCoordinate2D? = nil

    // MARK: - Private state

    /// Continuation that bridges the delegate callback to async/await.
    /// We hold at most one continuation at a time (one-shot pattern).
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
        // Request permission only if we haven't asked before.
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // The actual fix will be triggered after the delegate fires
            // (locationManagerDidChangeAuthorization). Returning here prevents
            // a race condition where requestLocation() fires before the OS
            // grants permission, which would immediately fail.
            return
        }

        // If the user denied access, show a descriptive fallback string.
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            startPlaceDescription = "Location access denied"
            return
        }

        // Fetch the one-shot fix via the async bridge.
        await fetchAndGeocode()
    }

    // MARK: - Private helpers

    /// Requests a single location fix using async/await and then
    /// reverse-geocodes the result into a short place string.
    private func fetchAndGeocode() async {
        do {
            // Suspend here until the delegate delivers a location (or an error).
            let location = try await withCheckedThrowingContinuation { continuation in
                // Store the continuation so the delegate can resume it.
                locationContinuation = continuation
                // This triggers one fix and then stops; no continuous updates.
                locationManager.requestLocation()
            }

            // Store the raw coordinate for any caller that needs it.
            startCoordinate = location.coordinate

            // Reverse-geocode: converts lat/lon to a list of placemarks.
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            if let placemark = placemarks.first {
                // Build a short "City, Province/State" string from the placemark.
                // administrativeArea is the province/state (e.g. "ON").
                let city   = placemark.locality ?? placemark.subLocality ?? ""
                let region = placemark.administrativeArea ?? ""

                if city.isEmpty && region.isEmpty {
                    // Fall back to country name if city/region both missing.
                    startPlaceDescription = placemark.country ?? "Unknown location"
                } else if city.isEmpty {
                    startPlaceDescription = region
                } else if region.isEmpty {
                    startPlaceDescription = city
                } else {
                    startPlaceDescription = "\(city), \(region)"
                }
            } else {
                startPlaceDescription = "Unknown location"
            }

        } catch {
            // Location or geocoding failed — set a safe fallback, never crash.
            print("LocationManager error: \(error.localizedDescription)")
            startPlaceDescription = "Location unavailable"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// Called when the user responds to the permission prompt.
    /// If permission was just granted, kick off the actual location fix.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            // Permission just granted — go ahead and capture the origin.
            Task { await fetchAndGeocode() }
        } else if status == .denied || status == .restricted {
            startPlaceDescription = "Location access denied"
        }
        // .notDetermined means the sheet is still visible; do nothing yet.
    }

    /// Delivers the one-shot location fix back to the async continuation.
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Resume the suspended continuation with the first valid fix.
        locationContinuation?.resume(returning: location)
        locationContinuation = nil  // Prevent double-resume
    }

    /// Delivers location errors back to the async continuation.
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil  // Prevent double-resume
    }
}

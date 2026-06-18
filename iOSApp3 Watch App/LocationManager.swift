//
//  LocationManager.swift
//  iOSApp3 Watch App
//
//  Created by Etefworkie Melaku
//

import Combine       // ObservableObject, @Published
import Foundation
import CoreLocation
import MapKit        // MKReverseGeocodingRequest (watchOS 26+ replacement for CLGeocoder)

// MARK: - LocationManager

@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Core Location

    private let locationManager = CLLocationManager()

    // MARK: - Published properties

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationAvailable: Bool = false

    /// City and region of the walk's origin fix, e.g. "Toronto, ON". Nil if location is off.
    @Published var startPlaceDescription: String? = nil

    // MARK: - Private state

    // Bridges the CLLocationManager delegate to async/await — one continuation at a time.
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // MARK: - Initializer

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        let status = locationManager.authorizationStatus
        authorizationStatus = status
        locationAvailable = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    // MARK: - Public API

    /// Always returns cleanly — session always records with time only if location is unavailable.
    func captureOrigin() async {
        startPlaceDescription = nil

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            await fetchAndGeocode()
        default:
            break
        }
    }

    // MARK: - Private helpers

    private func fetchAndGeocode() async {
        do {
            // requestLocation() triggers exactly one fix then stops.
            let location = try await withCheckedThrowingContinuation { continuation in
                locationContinuation = continuation
                locationManager.requestLocation()
            }

            // MKReverseGeocodingRequest: watchOS 26+ replacement for the deprecated CLGeocoder.
            guard let request = MKReverseGeocodingRequest(location: location) else { return }

            let mapItems: [MKMapItem]? = await withCheckedContinuation { continuation in
                request.getMapItems { items, error in
                    if let error { print("Reverse geocoding error: \(error.localizedDescription)") }
                    continuation.resume(returning: items)
                }
            }

            // cityWithContext(.automatic) returns "City, Region" format.
            if let representations = mapItems?.first?.addressRepresentations {
                startPlaceDescription = representations.cityWithContext(.automatic)
                    ?? representations.cityName
            }

        } catch {
            print("LocationManager error: \(error.localizedDescription)")
        }
    }
}

// MARK: - CLLocationManagerDelegate

// @preconcurrency: CLLocationManagerDelegate predates strict concurrency; callbacks arrive on main thread.
extension LocationManager: @preconcurrency CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status
        locationAvailable = (status == .authorizedWhenInUse || status == .authorizedAlways)

        if locationAvailable {
            // Permission just granted — fetch place so it can be appended to the in-progress session.
            Task { await fetchAndGeocode() }
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}

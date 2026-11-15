import CoreLocation
import Foundation
import Observation

/// Asks for the device location once (while the app is open) to compute prayer times.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle, locating, denied, failed
    }

    var state: State = .idle
    /// Called on the main actor with the found coordinate.
    var onLocation: ((Double, Double) -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestOnce() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .locating
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .denied
        default:
            state = .locating
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.state == .locating { self.manager.requestLocation() }
            case .denied, .restricted:
                self.state = .denied
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let lat = coordinate.latitude, lon = coordinate.longitude
        Task { @MainActor in
            self.state = .idle
            self.onLocation?(lat, lon)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if self.state == .locating { self.state = .failed }
        }
    }
}

import CoreLocation
import Foundation
import MapKit
import os

enum PlaceFinder {
    struct Place: Equatable, Sendable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    @MainActor
    static func find(_ query: String, nearLatitude: Double? = nil, nearLongitude: Double? = nil) async -> Place? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        var center = CLLocationManager().location?.coordinate
        if let nearLatitude, let nearLongitude {
            center = CLLocationCoordinate2D(latitude: nearLatitude, longitude: nearLongitude)
        }
        if let center {
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
        }
        do {
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { return nil }
            let coordinate = item.location.coordinate
            return Place(name: item.name ?? query, latitude: coordinate.latitude, longitude: coordinate.longitude)
        } catch {
            Logger.ingest.error("no place found for \(query, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

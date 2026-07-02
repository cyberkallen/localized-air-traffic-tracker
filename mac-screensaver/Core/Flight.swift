import Foundation

public struct Flight: Equatable, Sendable {
    public let id: String
    public let callsign: String
    public let airline: String
    public let aircraftType: String
    public let registration: String
    public let originCity: String
    public let destinationCity: String
    public let altitudeFt: Int
    public let speedKt: Int
    public let distanceKm: Double
    public let phase: FlightPhase
    public let squawk: String?
    public let hex: String?
    public let category: String?
    public let latitude: Double?
    public let longitude: Double?
    public let track: Double?

    public init(
        id: String,
        callsign: String,
        airline: String,
        aircraftType: String,
        registration: String,
        originCity: String,
        destinationCity: String,
        altitudeFt: Int,
        speedKt: Int,
        distanceKm: Double,
        phase: FlightPhase,
        squawk: String?,
        hex: String? = nil,
        category: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        track: Double? = nil
    ) {
        self.id = id
        self.callsign = callsign
        self.airline = airline
        self.aircraftType = aircraftType
        self.registration = registration
        self.originCity = originCity
        self.destinationCity = destinationCity
        self.altitudeFt = altitudeFt
        self.speedKt = speedKt
        self.distanceKm = distanceKm
        self.phase = phase
        self.squawk = squawk
        self.hex = hex
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.track = track
    }

    public var isEmergency: Bool {
        squawk == "7700" || squawk == "7600" || squawk == "7500"
    }

    public var isGroundVehicle: Bool {
        guard let cat = category?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
            return false
        }
        return cat.hasPrefix("C")
    }

    public var isNonAircraft: Bool {
        guard let h = hex?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return h.hasPrefix("~")
    }
}

public extension Flight {
    func isInsideGeofence(radiusKm: Double) -> Bool {
        distanceKm <= radiusKm
    }

    var mapHeadingDegrees: Double {
        guard let track else { return 0 }
        return track
    }

    static func bearingDegrees(
        fromLatitude startLatitude: Double,
        longitude startLongitude: Double,
        toLatitude endLatitude: Double,
        longitude endLongitude: Double
    ) -> Double {
        let startLat = startLatitude * .pi / 180
        let endLat = endLatitude * .pi / 180
        let deltaLon = (endLongitude - startLongitude) * .pi / 180

        let y = sin(deltaLon) * cos(endLat)
        let x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(deltaLon)
        let bearing = atan2(y, x) * 180 / .pi

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

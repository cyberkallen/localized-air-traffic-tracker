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
        squawk: String?
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
    }

    public var isEmergency: Bool {
        squawk == "7700" || squawk == "7600" || squawk == "7500"
    }
}

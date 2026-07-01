import Foundation

public struct Flight: Equatable, Codable, Sendable {
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

    private enum CodingKeys: String, CodingKey {
        case id
        case callsign = "flight"
        case airline
        case aircraftType = "type"
        case registration = "reg"
        case originCity
        case destinationCity
        case altitudeFt
        case speedKt
        case distanceKm
        case phase
        case squawk
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        callsign = try container.decode(String.self, forKey: .callsign)
        airline = try container.decode(String.self, forKey: .airline)
        aircraftType = try container.decode(String.self, forKey: .aircraftType)
        registration = try container.decode(String.self, forKey: .registration)
        originCity = try container.decode(String.self, forKey: .originCity)
        destinationCity = try container.decode(String.self, forKey: .destinationCity)
        altitudeFt = try container.decode(Int.self, forKey: .altitudeFt)
        speedKt = try container.decode(Int.self, forKey: .speedKt)
        distanceKm = try container.decode(Double.self, forKey: .distanceKm)
        phase = FlightPhase(rawValue: (try container.decodeIfPresent(String.self, forKey: .phase)) ?? "") ?? .unknown
        squawk = try container.decodeIfPresent(String.self, forKey: .squawk)
    }

    public var isEmergency: Bool {
        squawk == "7700" || squawk == "7600" || squawk == "7500"
    }
}

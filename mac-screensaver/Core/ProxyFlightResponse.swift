import Foundation

public struct ProxyFlightResponse: Decodable, Sendable {
    public let flights: [Flight]

    private enum CodingKeys: String, CodingKey {
        case flights
    }

    private struct FlightPayload: Decodable {
        let id: String
        let callsign: String
        let airline: String
        let aircraftType: String
        let registration: String
        let originCity: String
        let destinationCity: String
        let altitudeFt: Int
        let speedKt: Int
        let distanceKm: Double
        let phase: FlightPhase
        let squawk: String?

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

        init(from decoder: Decoder) throws {
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payloads = try container.decode([FlightPayload].self, forKey: .flights)
        flights = payloads.map {
            Flight(
                id: $0.id,
                callsign: $0.callsign,
                airline: $0.airline,
                aircraftType: $0.aircraftType,
                registration: $0.registration,
                originCity: $0.originCity,
                destinationCity: $0.destinationCity,
                altitudeFt: $0.altitudeFt,
                speedKt: $0.speedKt,
                distanceKm: $0.distanceKm,
                phase: $0.phase,
                squawk: $0.squawk
            )
        }
    }
}

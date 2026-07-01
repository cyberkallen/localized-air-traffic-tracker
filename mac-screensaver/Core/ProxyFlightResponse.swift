import Foundation

public struct ProxyFlightResponse: Decodable, Sendable {
    public let flights: [Flight]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let payloads = try container.decodeIfPresent([FlightPayload].self, forKey: .flights) {
            flights = payloads.map(\.flight)
            return
        }

        let aircraft = try container.decodeIfPresent([AircraftPayload].self, forKey: .ac) ?? []
        flights = aircraft.map(\.flight)
    }

    public init(flights: [Flight]) {
        self.flights = flights
    }

    private enum CodingKeys: String, CodingKey {
        case flights
        case ac
    }
}

private struct FlightPayload: Decodable, Sendable {
    let flight: Flight

    private enum CodingKeys: String, CodingKey {
        case id
        case flight
        case airline
        case type
        case reg
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
        let phase = try container.decodeIfPresent(String.self, forKey: .phase)

        flight = Flight(
            id: try container.decode(String.self, forKey: .id),
            callsign: try container.decode(String.self, forKey: .flight),
            airline: try container.decode(String.self, forKey: .airline),
            aircraftType: try container.decode(String.self, forKey: .type),
            registration: try container.decode(String.self, forKey: .reg),
            originCity: try container.decode(String.self, forKey: .originCity),
            destinationCity: try container.decode(String.self, forKey: .destinationCity),
            altitudeFt: try container.decode(Int.self, forKey: .altitudeFt),
            speedKt: try container.decode(Int.self, forKey: .speedKt),
            distanceKm: try container.decode(Double.self, forKey: .distanceKm),
            phase: FlightPhase(rawValue: phase ?? "") ?? .unknown,
            squawk: try container.decodeIfPresent(String.self, forKey: .squawk)
        )
    }
}

private struct AircraftPayload: Decodable, Sendable {
    let flight: Flight

    private enum CodingKeys: String, CodingKey {
        case hex
        case flight
        case ownOp
        case desc
        case type
        case t
        case registration = "r"
        case altBaro = "alt_baro"
        case groundSpeed = "gs"
        case distanceKm = "dst"
        case dep
        case arr
        case squawk
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let callsign = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .flight))
        let operatorName = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .ownOp))
        let description = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .desc))
        let aircraftType = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .t))
            ?? Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .type))
            ?? description
        let registration = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .registration))
        let originCity = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .dep)) ?? "Unknown"
        let destinationCity = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .arr)) ?? "Unknown"
        let altitudeFt = Self.decodeInt(container, key: .altBaro)
        let speedKt = Self.roundedInt(Self.decodeDouble(container, key: .groundSpeed))
        let distanceKm = Self.decodeDouble(container, key: .distanceKm)
        let squawk = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .squawk))

        flight = Flight(
            id: Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .hex)) ?? callsign ?? "UNKNOWN",
            callsign: callsign ?? Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .hex)) ?? "UNKNOWN",
            airline: operatorName ?? description ?? "Unknown",
            aircraftType: aircraftType ?? "Unknown",
            registration: registration ?? "Unknown",
            originCity: originCity,
            destinationCity: destinationCity,
            altitudeFt: altitudeFt,
            speedKt: speedKt,
            distanceKm: distanceKm,
            phase: .unknown,
            squawk: squawk
        )
    }

    private static func trimmed(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let result, !result.isEmpty else { return nil }
        return result
    }

    private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int {
        (try? container.decodeIfPresent(Int.self, forKey: key)) ?? 0
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        (try? container.decodeIfPresent(Double.self, forKey: key)) ?? 0
    }

    private static func roundedInt(_ value: Double?) -> Int {
        guard let value else { return 0 }
        return Int(value.rounded())
    }
}

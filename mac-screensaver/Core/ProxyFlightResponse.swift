import Foundation

public struct ProxyFlightResponse: Decodable, Sendable {
    public let flights: [Flight]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flights = try container.decode([Flight].self, forKey: .flights)
    }

    public init(flights: [Flight]) {
        self.flights = flights
    }

    private enum CodingKeys: String, CodingKey {
        case flights
    }
}

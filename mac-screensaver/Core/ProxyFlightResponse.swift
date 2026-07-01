import Foundation

public struct ProxyFlightResponse: Codable, Sendable {
    public let flights: [Flight]

    public init(flights: [Flight]) {
        self.flights = flights
    }
}

import Foundation
import OverheadTrackerScreensaverCore

public struct FlightFeedClient {
    let session: URLSession
    let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.overheadtracker.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func fetchFlights() async throws -> [Flight] {
        let url = baseURL.appendingPathComponent("flights")
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(ProxyFlightResponse.self, from: data)
        return FlightOrderer.closestFirst(decoded.flights)
    }
}

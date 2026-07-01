import Foundation

public enum ScreensaverState: Equatable, Sendable {
    case loading
    case live([Flight], index: Int)
    case noFlights
    case offline(message: String)

    public static func liveOrEmpty(flights: [Flight]) -> ScreensaverState {
        flights.isEmpty ? .noFlights : .live(flights, index: 0)
    }
}

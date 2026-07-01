import Foundation

public enum FlightPhase: String, Codable, Sendable {
    case takeoff
    case climbing
    case cruising
    case descending
    case approach
    case landing
    case overhead
    case unknown
}

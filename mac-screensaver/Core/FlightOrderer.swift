import Foundation

public enum FlightOrderer {
    public static func closestFirst(_ flights: [Flight]) -> [Flight] {
        flights.sorted {
            if $0.distanceKm != $1.distanceKm {
                return $0.distanceKm < $1.distanceKm
            }

            return $0.id < $1.id
        }
    }
}

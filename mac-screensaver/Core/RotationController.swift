import Combine
import Foundation

@MainActor
public final class RotationController: ObservableObject {
    @Published public private(set) var currentFlight: Flight?

    private var flights: [Flight] = []
    private var index: Int = 0

    public init(flights: [Flight]) {
        update(flights: flights)
    }

    public func update(flights: [Flight]) {
        self.flights = FlightOrderer.closestFirst(flights)
        index = 0
        currentFlight = self.flights.first
    }

    public func advance() {
        guard !flights.isEmpty else {
            currentFlight = nil
            return
        }

        index = (index + 1) % flights.count
        currentFlight = flights[index]
    }
}

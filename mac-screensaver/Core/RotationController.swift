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
        let orderedFlights = FlightOrderer.closestFirst(flights)
        let currentFlightID = currentFlight?.id

        self.flights = orderedFlights

        guard !orderedFlights.isEmpty else {
            index = 0
            currentFlight = nil
            return
        }

        if let currentFlightID,
           let retainedIndex = orderedFlights.firstIndex(where: { $0.id == currentFlightID }) {
            index = retainedIndex
            currentFlight = orderedFlights[retainedIndex]
            return
        }

        index = 0
        currentFlight = orderedFlights.first
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

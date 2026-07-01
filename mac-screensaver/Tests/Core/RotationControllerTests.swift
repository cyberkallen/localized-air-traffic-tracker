import XCTest
@testable import OverheadTrackerScreensaverCore

@MainActor
final class RotationControllerTests: XCTestCase {
    func testRotationAdvancesByClosestFirstOrder() {
        let flights = [
            Flight(id: "1", callsign: "QFA1", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNA", originCity: "Sydney", destinationCity: "Melbourne", altitudeFt: 36000, speedKt: 470, distanceKm: 2.0, phase: .approach, squawk: nil),
            Flight(id: "2", callsign: "QFA2", airline: "Qantas", aircraftType: "A320", registration: "VH-VQS", originCity: "Adelaide", destinationCity: "Sydney", altitudeFt: 12000, speedKt: 320, distanceKm: 5.0, phase: .descending, squawk: nil)
        ]

        let controller = RotationController(flights: flights)
        XCTAssertEqual(controller.currentFlight?.callsign, "QFA1")
        controller.advance()
        XCTAssertEqual(controller.currentFlight?.callsign, "QFA2")
    }

    func testUpdatePreservesTheCurrentFlightWhenItStillExists() {
        let flights = [
            Flight(id: "1", callsign: "QFA1", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNA", originCity: "Sydney", destinationCity: "Melbourne", altitudeFt: 36000, speedKt: 470, distanceKm: 2.0, phase: .approach, squawk: nil),
            Flight(id: "2", callsign: "QFA2", airline: "Qantas", aircraftType: "A320", registration: "VH-VQS", originCity: "Adelaide", destinationCity: "Sydney", altitudeFt: 12000, speedKt: 320, distanceKm: 5.0, phase: .descending, squawk: nil)
        ]

        let controller = RotationController(flights: flights)
        controller.advance()
        controller.update(flights: flights.reversed())
        XCTAssertEqual(controller.currentFlight?.callsign, "QFA2")
    }

    func testUpdateFallsBackToClosestFlightWhenCurrentFlightDropsOut() {
        let flights = [
            Flight(id: "1", callsign: "QFA1", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNA", originCity: "Sydney", destinationCity: "Melbourne", altitudeFt: 36000, speedKt: 470, distanceKm: 2.0, phase: .approach, squawk: nil),
            Flight(id: "2", callsign: "QFA2", airline: "Qantas", aircraftType: "A320", registration: "VH-VQS", originCity: "Adelaide", destinationCity: "Sydney", altitudeFt: 12000, speedKt: 320, distanceKm: 5.0, phase: .descending, squawk: nil)
        ]

        let controller = RotationController(flights: flights)
        controller.advance()
        controller.update(flights: [flights[0]])
        XCTAssertEqual(controller.currentFlight?.callsign, "QFA1")
    }
}

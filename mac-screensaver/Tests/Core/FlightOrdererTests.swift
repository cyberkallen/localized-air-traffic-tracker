import XCTest
@testable import OverheadTrackerScreensaverCore

final class FlightOrdererTests: XCTestCase {
    func testClosestFlightsComeFirst() {
        let flights = [
            Flight(id: "3", callsign: "QFA3", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNC", originCity: "Brisbane", destinationCity: "Sydney", altitudeFt: 34000, speedKt: 460, distanceKm: 9.0, phase: .cruising, squawk: nil),
            Flight(id: "1", callsign: "QFA1", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNA", originCity: "Sydney", destinationCity: "Melbourne", altitudeFt: 36000, speedKt: 470, distanceKm: 2.0, phase: .approach, squawk: nil),
            Flight(id: "2", callsign: "QFA2", airline: "Qantas", aircraftType: "A320", registration: "VH-VQS", originCity: "Adelaide", destinationCity: "Sydney", altitudeFt: 12000, speedKt: 320, distanceKm: 5.0, phase: .descending, squawk: nil)
        ]

        let ordered = FlightOrderer.closestFirst(flights)
        XCTAssertEqual(ordered.map(\.callsign), ["QFA1", "QFA2", "QFA3"])
    }

    func testEqualDistancesUseDeterministicTieBreak() {
        let flights = [
            Flight(id: "b", callsign: "QFA9", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNB", originCity: "Brisbane", destinationCity: "Sydney", altitudeFt: 34000, speedKt: 460, distanceKm: 4.0, phase: .cruising, squawk: nil),
            Flight(id: "a", callsign: "QFA1", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNA", originCity: "Sydney", destinationCity: "Melbourne", altitudeFt: 36000, speedKt: 470, distanceKm: 4.0, phase: .approach, squawk: nil)
        ]

        let ordered = FlightOrderer.closestFirst(flights)
        XCTAssertEqual(ordered.map(\.callsign), ["QFA1", "QFA9"])
    }
}

import XCTest
@testable import OverheadTrackerScreensaverCore

final class FlightPhaseTests: XCTestCase {
    func testFlightPhaseRawValuesAreStable() {
        XCTAssertEqual(FlightPhase.takeoff.rawValue, "takeoff")
        XCTAssertEqual(FlightPhase.climbing.rawValue, "climbing")
        XCTAssertEqual(FlightPhase.cruising.rawValue, "cruising")
        XCTAssertEqual(FlightPhase.descending.rawValue, "descending")
        XCTAssertEqual(FlightPhase.approach.rawValue, "approach")
        XCTAssertEqual(FlightPhase.landing.rawValue, "landing")
        XCTAssertEqual(FlightPhase.overhead.rawValue, "overhead")
        XCTAssertEqual(FlightPhase.unknown.rawValue, "unknown")
    }

    func testEmergencySquawkSetsEmergencyFlag() {
        let flight = Flight(
            id: "abc123",
            callsign: "QFA1",
            airline: "Qantas",
            aircraftType: "B789",
            registration: "VH-ZNA",
            originCity: "Sydney",
            destinationCity: "Melbourne",
            altitudeFt: 35000,
            speedKt: 460,
            distanceKm: 8.2,
            phase: .cruising,
            squawk: "7700"
        )

        XCTAssertTrue(flight.isEmergency)
    }
}

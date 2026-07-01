import XCTest
@testable import OverheadTrackerScreensaverCore

final class FlightPhaseTests: XCTestCase {
    func testEmergencySquawkMapsToRedOverride() {
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

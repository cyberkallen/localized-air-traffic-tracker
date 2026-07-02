import XCTest
@testable import OverheadTrackerScreensaverCore

final class FlightPresentationTests: XCTestCase {
    func testIsInsideGeofenceTreatsBoundaryAsInside() {
        let flight = Flight(
            id: "1",
            callsign: "QFA1",
            airline: "Qantas",
            aircraftType: "B789",
            registration: "VH-ZNA",
            originCity: "Sydney",
            destinationCity: "Melbourne",
            altitudeFt: 36000,
            speedKt: 470,
            distanceKm: 5.0,
            phase: .cruising,
            squawk: nil
        )

        XCTAssertTrue(flight.isInsideGeofence(radiusKm: 5.0))
        XCTAssertFalse(flight.isInsideGeofence(radiusKm: 4.99))
    }

    func testMapHeadingDegreesOffsetsTheAirplaneSymbolToTrueNorth() {
        let flight = Flight(
            id: "1",
            callsign: "QFA1",
            airline: "Qantas",
            aircraftType: "B789",
            registration: "VH-ZNA",
            originCity: "Sydney",
            destinationCity: "Melbourne",
            altitudeFt: 36000,
            speedKt: 470,
            distanceKm: 5.0,
            phase: .cruising,
            squawk: nil,
            track: 0
        )

        XCTAssertEqual(flight.mapHeadingDegrees, 0)
    }

    func testBearingDegreesMatchesCardinalDirections() {
        XCTAssertEqual(
            Flight.bearingDegrees(
                fromLatitude: 0,
                longitude: 0,
                toLatitude: 1,
                longitude: 0
            ),
            0,
            accuracy: 0.0001
        )

        XCTAssertEqual(
            Flight.bearingDegrees(
                fromLatitude: 0,
                longitude: 0,
                toLatitude: 0,
                longitude: 1
            ),
            90,
            accuracy: 0.0001
        )
    }
}

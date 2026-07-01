import XCTest
@testable import OverheadTrackerScreensaverCore

final class ProxyFlightResponseTests: XCTestCase {
    func testProxyPayloadMapsToFlightModel() throws {
        let json = #"""
        {
          "flights": [
            {
              "id": "abc123",
              "flight": "QFA1",
              "airline": "Qantas",
              "type": "B789",
              "reg": "VH-ZNA",
              "originCity": "Sydney",
              "destinationCity": "Melbourne",
              "altitudeFt": 35000,
              "speedKt": 460,
              "distanceKm": 8.2,
              "phase": "cruising",
              "squawk": "1200"
            }
          ]
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ProxyFlightResponse.self, from: json)
        XCTAssertEqual(decoded.flights.first?.callsign, "QFA1")
        XCTAssertEqual(decoded.flights.first?.phase, .cruising)
    }

    func testLiveProxyPayloadMapsFromRawAircraftArray() throws {
        let json = #"""
        {
          "ac": [
            {
              "hex": "7cb0db",
              "flight": "87X     ",
              "r": "VH-87X",
              "t": "E55P",
              "ownOp": "SPECIAL MINING SERVICES PTY LTD",
              "desc": "EMBRAER EMB-505 Phenom 300",
              "alt_baro": 2500,
              "gs": 232.9,
              "dst": 19.742,
              "squawk": "1115"
            }
          ]
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ProxyFlightResponse.self, from: json)
        XCTAssertEqual(decoded.flights.first?.id, "7cb0db")
        XCTAssertEqual(decoded.flights.first?.callsign, "87X")
        XCTAssertEqual(decoded.flights.first?.airline, "SPECIAL MINING SERVICES PTY LTD")
        XCTAssertEqual(decoded.flights.first?.aircraftType, "E55P")
        XCTAssertEqual(decoded.flights.first?.registration, "VH-87X")
        XCTAssertEqual(decoded.flights.first?.altitudeFt, 2500)
        XCTAssertEqual(decoded.flights.first?.speedKt, 233)
        XCTAssertEqual(decoded.flights.first?.distanceKm, 19.742)
        XCTAssertEqual(decoded.flights.first?.squawk, "1115")
        XCTAssertEqual(decoded.flights.first?.hex, "7cb0db")
    }

    func testUnknownPhaseFallsBackToUnknown() throws {
        let json = #"""
        {
          "flights": [
            {
              "id": "abc123",
              "flight": "QFA1",
              "airline": "Qantas",
              "type": "B789",
              "reg": "VH-ZNA",
              "originCity": "Sydney",
              "destinationCity": "Melbourne",
              "altitudeFt": 35000,
              "speedKt": 460,
              "distanceKm": 8.2,
              "phase": "made-up",
              "squawk": "1200"
            }
          ]
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ProxyFlightResponse.self, from: json)
        XCTAssertEqual(decoded.flights.first?.phase, .unknown)
    }
}

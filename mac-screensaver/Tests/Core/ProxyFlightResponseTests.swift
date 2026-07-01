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
}

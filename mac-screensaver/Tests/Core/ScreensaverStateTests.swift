import XCTest
@testable import OverheadTrackerScreensaverCore

final class ScreensaverStateTests: XCTestCase {
    func testNoFlightsProducesNoFlightsState() {
        let state = ScreensaverState.liveOrEmpty(flights: [])
        XCTAssertEqual(state, .noFlights)
    }
}

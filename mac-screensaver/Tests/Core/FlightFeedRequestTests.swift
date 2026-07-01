import XCTest
@testable import OverheadTrackerScreensaverCore

final class FlightFeedRequestTests: XCTestCase {
    func testBuildsFlightsURLWithLocationQueryParameters() throws {
        let url = try FlightFeedRequest.flightsURL(
            baseURL: URL(string: "https://api.overheadtracker.com")!,
            homeLatitude: -33.8530,
            homeLongitude: 151.1410,
            radiusNm: 20
        )

        XCTAssertEqual(url.absoluteString, "https://api.overheadtracker.com/flights?lat=-33.853&lon=151.141&radius=20")
    }
}

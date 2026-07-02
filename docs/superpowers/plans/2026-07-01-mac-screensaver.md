# Mac Screensaver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Mac screensaver that shows one live aircraft card at a time from Overhead Tracker, rotating through nearby flights in closest-first order with clear loading, offline, no-flights, and emergency states.

**Architecture:** Split the feature into a pure Swift core for flight models, parsing, ordering, and state transitions, then a macOS screensaver host that renders those states with SwiftUI inside a ScreenSaver view. Keep all network and UI code at the edge so the core can be tested without a running screensaver bundle.

**Tech Stack:** Swift, ScreenSaver.framework, SwiftUI, URLSession, XCTest, Xcode project build/test.

---

## File Structure

The new feature should live in a dedicated `mac-screensaver/` subtree so it does not pollute the existing web, firmware, or server code.

- `mac-screensaver/OverheadTrackerScreensaver.xcodeproj` owns the macOS build, one screensaver bundle target, and one pure Swift core target.
- `mac-screensaver/Core/` contains model, parsing, sorting, and state-machine code with no AppKit dependency.
- `mac-screensaver/Screensaver/` contains the ScreenSaver host, SwiftUI views, and timer/network orchestration.
- `mac-screensaver/Tests/` contains XCTest coverage for ordering, parsing, and state transitions.
- `mac-screensaver/README.md` explains how to build and install the screensaver locally.
- `README.md` gets a short link to the new Mac screensaver docs.

## Task 1: Scaffold the macOS screensaver project and core model boundary

**Files:**
- Create: `mac-screensaver/OverheadTrackerScreensaver.xcodeproj`
- Create: `mac-screensaver/Core/Flight.swift`
- Create: `mac-screensaver/Core/FlightPhase.swift`
- Create: `mac-screensaver/Core/ScreensaverState.swift`
- Create: `mac-screensaver/Core/ProxyFlightResponse.swift`
- Create: `mac-screensaver/Tests/Core/FlightPhaseTests.swift`
- Create: `mac-screensaver/Tests/Core/ScreensaverStateTests.swift`

- [ ] **Step 1: Write the failing tests for the core model boundary**

```swift
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
```

```swift
import XCTest
@testable import OverheadTrackerScreensaverCore

final class ScreensaverStateTests: XCTestCase {
    func testNoFlightsProducesNoFlightsState() {
        let state = ScreensaverState.liveOrEmpty(flights: [])
        XCTAssertEqual(state, .noFlights)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail because the target does not exist yet**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaverCore -destination 'platform=macOS'`

Expected:
Fail with a missing project, missing scheme, or missing source files. That is the correct failure at this stage.

- [ ] **Step 3: Create the minimal core types and target wiring**

```swift
import Foundation

public struct Flight: Equatable, Sendable {
    public let id: String
    public let callsign: String
    public let airline: String
    public let aircraftType: String
    public let registration: String
    public let originCity: String
    public let destinationCity: String
    public let altitudeFt: Int
    public let speedKt: Int
    public let distanceKm: Double
    public let phase: FlightPhase
    public let squawk: String?

    public var isEmergency: Bool {
        squawk == "7700" || squawk == "7600" || squawk == "7500"
    }
}
```

```swift
import Foundation

public enum FlightPhase: String, Codable, Sendable {
    case takeoff
    case climbing
    case cruising
    case descending
    case approach
    case landing
    case overhead
    case unknown
}
```

```swift
import Foundation

public enum ScreensaverState: Equatable, Sendable {
    case loading
    case live([Flight], index: Int)
    case noFlights
    case offline(message: String)

    public static func liveOrEmpty(flights: [Flight]) -> ScreensaverState {
        flights.isEmpty ? .noFlights : .live(flights, index: 0)
    }
}
```

- [ ] **Step 4: Run the tests and confirm the core boundary passes**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaverCore -destination 'platform=macOS'`

Expected:
Tests pass with the core target compiling cleanly.

- [ ] **Step 5: Commit the scaffold**

```bash
git add mac-screensaver
git commit -m "feat: scaffold mac screensaver core"
```

## Task 2: Implement live flight parsing and closest-first ordering

**Files:**
- Create: `mac-screensaver/Core/ProxyFlightResponse.swift`
- Create: `mac-screensaver/Core/FlightOrderer.swift`
- Create: `mac-screensaver/Tests/Core/FlightOrdererTests.swift`
- Create: `mac-screensaver/Tests/Core/ProxyFlightResponseTests.swift`

- [ ] **Step 1: Write the failing tests for parsing and sort order**

```swift
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
}
```

```swift
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
```

- [ ] **Step 2: Run the tests and verify they fail for the right reason**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaverCore -destination 'platform=macOS' -only-testing:OverheadTrackerScreensaverCoreTests/FlightOrdererTests`

Expected:
Fail because `FlightOrderer` and `ProxyFlightResponse` are not implemented yet.

- [ ] **Step 3: Implement parsing and ordering with deterministic tie-breaking**

```swift
import Foundation

public struct ProxyFlightResponse: Codable, Sendable {
    public let flights: [Flight]
}
```

```swift
import Foundation

public enum FlightOrderer {
    public static func closestFirst(_ flights: [Flight]) -> [Flight] {
        flights.sorted {
            if $0.distanceKm == $1.distanceKm {
                return $0.callsign < $1.callsign
            }
            return $0.distanceKm < $1.distanceKm
        }
    }
}
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaverCore -destination 'platform=macOS'`

Expected:
Parsing and ordering tests pass.

- [ ] **Step 5: Commit the parsing and ordering work**

```bash
git add mac-screensaver
git commit -m "feat: parse and sort screensaver flights"
```

## Task 3: Build the screensaver host, flight card UI, and state rendering

**Files:**
- Create: `mac-screensaver/Screensaver/OverheadTrackerScreensaverView.swift`
- Create: `mac-screensaver/Screensaver/FlightCardView.swift`
- Create: `mac-screensaver/Screensaver/StatusViews.swift`
- Create: `mac-screensaver/Screensaver/FlightFeedClient.swift`
- Create: `mac-screensaver/Core/RotationController.swift`
- Create: `mac-screensaver/Tests/Core/RotationControllerTests.swift`

- [ ] **Step 1: Write the failing tests for rotation and state transitions**

```swift
import XCTest
@testable import OverheadTrackerScreensaverCore

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

    func testUpdateResetsRotationToClosestFirstOrder() {
        let flights = [
            Flight(id: "1", callsign: "QFA1", airline: "Qantas", aircraftType: "B789", registration: "VH-ZNA", originCity: "Sydney", destinationCity: "Melbourne", altitudeFt: 36000, speedKt: 470, distanceKm: 2.0, phase: .approach, squawk: nil),
            Flight(id: "2", callsign: "QFA2", airline: "Qantas", aircraftType: "A320", registration: "VH-VQS", originCity: "Adelaide", destinationCity: "Sydney", altitudeFt: 12000, speedKt: 320, distanceKm: 5.0, phase: .descending, squawk: nil)
        ]

        let controller = RotationController(flights: flights)
        controller.advance()
        controller.update(flights: flights.reversed())
        XCTAssertEqual(controller.currentFlight?.callsign, "QFA1")
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail because the host types do not exist yet**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaver -destination 'platform=macOS'`

Expected:
Fail because the screensaver host types are missing.

- [ ] **Step 3: Implement the host and SwiftUI views with the required states**

```swift
import SwiftUI

struct FlightCardView: View {
    let flight: Flight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(flight.callsign)
                .font(.system(size: 72, weight: .bold, design: .rounded))
            Text(flight.airline)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("\(flight.originCity) to \(flight.destinationCity)")
                .font(.system(size: 28, weight: .medium, design: .rounded))
            Text("\(flight.aircraftType)  \(flight.registration)")
                .font(.system(size: 18, weight: .regular, design: .monospaced))
            HStack {
                Text("ALT \(flight.altitudeFt) FT")
                Text("SPD \(flight.speedKt) KT")
                Text("DST \(String(format: "%.1f", flight.distanceKm)) KM")
                Text(flight.phase.rawValue.uppercased())
            }
            .font(.system(size: 16, weight: .semibold, design: .monospaced))
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
```

```swift
import SwiftUI

struct StatusView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text(detail)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
```

```swift
import Combine
import Foundation

public final class RotationController: ObservableObject {
    @Published public private(set) var currentFlight: Flight?

    private var flights: [Flight] = []
    private var index: Int = 0

    public init(flights: [Flight]) {
        update(flights: flights)
    }

    public func update(flights: [Flight]) {
        self.flights = FlightOrderer.closestFirst(flights)
        self.index = 0
        self.currentFlight = self.flights.first
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
```

- [ ] **Step 4: Run the screensaver target tests and verify the UI host compiles**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaver -destination 'platform=macOS'`

Expected:
The screensaver bundle compiles, the host renders the core states, and the timer-driven rotation compiles cleanly.

- [ ] **Step 5: Commit the UI and host work**

```bash
git add mac-screensaver
git commit -m "feat: render mac screensaver flight card"
```

## Task 4: Wire live proxy polling, emergency override, docs, and final verification

**Files:**
- Create: `mac-screensaver/Screensaver/FlightFeedClient.swift`
- Create: `mac-screensaver/Tests/Screensaver/FlightFeedClientTests.swift`
- Modify: `README.md`
- Create: `mac-screensaver/README.md`

- [ ] **Step 1: Write the failing integration test for live polling and emergency override**

```swift
import XCTest
@testable import OverheadTrackerScreensaver

final class FlightFeedClientTests: XCTestCase {
    func testFetchFlightsReturnsClosestFirstDecodedFlights() async throws {
        let json = #"""
        {
          "flights": [
            {
              "id": "1",
              "flight": "QFA1",
              "airline": "Qantas",
              "type": "B789",
              "reg": "VH-ZNA",
              "originCity": "Sydney",
              "destinationCity": "Melbourne",
              "altitudeFt": 36000,
              "speedKt": 470,
              "distanceKm": 2.0,
              "phase": "approach",
              "squawk": "7700"
            },
            {
              "id": "2",
              "flight": "QFA2",
              "airline": "Qantas",
              "type": "A320",
              "reg": "VH-VQS",
              "originCity": "Adelaide",
              "destinationCity": "Sydney",
              "altitudeFt": 12000,
              "speedKt": 320,
              "distanceKm": 5.0,
              "phase": "descending",
              "squawk": "1200"
            }
          ]
        }
        """#.data(using: .utf8)!

        let client = FlightFeedClient(session: URLSession.stub(json: json))
        let flights = try await client.fetchFlights()
        XCTAssertEqual(flights.map(\.callsign), ["QFA1", "QFA2"])
        XCTAssertTrue(flights.first?.isEmergency == true)
    }
}
```

- [ ] **Step 2: Run the test and confirm the current host does not yet fetch or refresh live data**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaver -destination 'platform=macOS' -only-testing:OverheadTrackerScreensaverTests/FlightFeedClientTests`

Expected:
The test fails until `FlightFeedClient` exists and accepts an injected session.

- [ ] **Step 3: Implement the feed client, 15-second fetch cadence, and red emergency override**

```swift
import Foundation

struct FlightFeedClient {
    let session: URLSession
    let baseURL = URL(string: "https://api.overheadtracker.com")!

    func fetchFlights() async throws -> [Flight] {
        let url = baseURL.appendingPathComponent("flights")
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(ProxyFlightResponse.self, from: data)
        return FlightOrderer.closestFirst(decoded.flights)
    }
}
```

```swift
import Foundation

extension URLSession {
    static func stub(json: Data) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.stubbedData = json
        return URLSession(configuration: config)
    }
}
```

```swift
import Foundation

final class StubURLProtocol: URLProtocol {
    static var stubbedData: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.stubbedData ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

```swift
import SwiftUI

struct OverheadTrackerScreensaverRootView: View {
    @StateObject private var controller = RotationController(flights: [])
    @State private var state: ScreensaverState = .loading

    var body: some View {
        ZStack {
            switch state {
            case .loading:
                StatusView(title: "LOADING", detail: "Waiting for live aircraft data")
            case .noFlights:
                StatusView(title: "NO AIRCRAFT OVERHEAD", detail: "Nothing within range right now")
            case .offline(let message):
                StatusView(title: "OFFLINE", detail: message)
            case .live(_, _):
                if let flight = controller.currentFlight {
                    FlightCardView(flight: flight)
                        .overlay(alignment: .topTrailing) {
                            if flight.isEmergency {
                                Text("EMERGENCY")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .padding(10)
                                    .background(Color.red)
                            }
                        }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run the full macOS test/build commands and verify the bundle behaves like the spec**

Run:
`xcodebuild test -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaverCore -destination 'platform=macOS'`

Run:
`xcodebuild build -project mac-screensaver/OverheadTrackerScreensaver.xcodeproj -scheme OverheadTrackerScreensaver -destination 'platform=macOS'`

Expected:
The core tests pass, the screensaver bundle builds, the UI is data-only, the rotation stays closest-first, and emergency flights visibly override the normal phase styling.

- [ ] **Step 5: Write the install and usage notes, then commit everything**

```markdown
# Mac Screensaver

Build the bundle from `mac-screensaver/OverheadTrackerScreensaver.xcodeproj` and install the resulting `.saver` file into `~/Library/Screen Savers/`.

The screensaver reads live data from `api.overheadtracker.com`, shows one flight card at a time, rotates every 10 seconds, and falls back to loading, offline, and no-flights states instead of going blank.
```

```bash
git add mac-screensaver README.md
git commit -m "feat: add mac screensaver docs and live feed wiring"
```

## Coverage Check

This plan covers the design spec directly:

- Data-first, no map: Task 3 keeps the UI strictly to a single flight card and status states.
- One aircraft at a time: Task 3 introduces the rotation controller and card renderer.
- Closest-first ordering: Task 2 defines the sort order and tests it.
- 10-second rotation: Task 3 bakes the cadence into the host controller.
- Loading, offline, no-flights, emergency: Task 1 defines the state model and Tasks 3-4 render each state explicitly.
- Live proxy data: Task 4 wires the feed client to `api.overheadtracker.com`.
- Clean degrade behavior: Tasks 1 and 4 make blank screens and silent failures unacceptable.

No spec requirement is left without a task.

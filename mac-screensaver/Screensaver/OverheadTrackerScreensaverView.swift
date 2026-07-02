import AppKit
import Combine
import ScreenSaver
import OverheadTrackerScreensaverCore
import os
import SwiftUI
import MapKit

private let screensaverLogger = Logger(subsystem: "com.overheadtracker.screensaver", category: "screensaver")

@MainActor
class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        return false
    }

    override func layout() {
        super.layout()
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }
}

@objc(OverheadTrackerScreensaverView)
@MainActor
public final class OverheadTrackerScreensaverView: ScreenSaverView {
    private let flightFeedClient = FlightFeedClient()
    private let rotationController = RotationController(flights: [])
    private let viewModel: ScreensaverViewModel
    private let hostingView: TransparentHostingView<OverheadTrackerScreensaverRootView>
    private var refreshTimer: Timer?
    private var rotationTimer: Timer?
    private var activeDataTask: URLSessionDataTask?
    private var loadingWatchdog: DispatchWorkItem?
    private var requestSequence = 0
    private var currentFlights: [Flight] = []
    private let previewMode: Bool

    public override init?(frame: NSRect, isPreview: Bool) {
        previewMode = isPreview
        let viewModel = ScreensaverViewModel()
        viewModel.homeLongitude = flightFeedClient.homeLongitude
        viewModel.geofenceRadiusKm = Double(flightFeedClient.radiusNm) * 1.852
        self.viewModel = viewModel
        hostingView = TransparentHostingView(rootView: OverheadTrackerScreensaverRootView(viewModel: viewModel))
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        animationTimeInterval = 1.0 / 30.0

        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false

        screensaverLogger.info("init preview=\(isPreview, privacy: .public)")
        startRefreshLoopIfNeeded()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func startAnimation() {
        screensaverLogger.info("startAnimation")
        super.startAnimation()
        startRefreshLoopIfNeeded()
    }

    public override func stopAnimation() {
        screensaverLogger.info("stopAnimation")
        refreshTimer?.invalidate()
        refreshTimer = nil
        rotationTimer?.invalidate()
        rotationTimer = nil
        activeDataTask?.cancel()
        activeDataTask = nil
        loadingWatchdog?.cancel()
        loadingWatchdog = nil
        super.stopAnimation()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        screensaverLogger.info("viewDidMoveToWindow window=\(self.window != nil, privacy: .public)")
        startRefreshLoopIfNeeded()
        
        let scale = window?.backingScaleFactor ?? 2.0
        triggerMapSnapshot(width: bounds.width, height: bounds.height, scale: scale)
    }

    private func triggerMapSnapshot(width: CGFloat, height: CGFloat, scale: CGFloat) {
        let options = MKMapSnapshotter.Options()
        let center = CLLocationCoordinate2D(
            latitude: flightFeedClient.homeLatitude,
            longitude: flightFeedClient.homeLongitude
        )
        let spanDelta = (Double(flightFeedClient.radiusNm) * 2.4) / 60.0
        options.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
        )
        options.size = NSSize(width: width, height: height)

        if #available(macOS 13.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            configuration.pointOfInterestFilter = .excludingAll
            configuration.showsTraffic = false
            options.preferredConfiguration = configuration
        } else {
            options.mapType = .mutedStandard
        }

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    screensaverLogger.error("Map snapshot failed: \(error.localizedDescription)")
                    return
                }
                if let snapshot = snapshot {
                    screensaverLogger.info("Map snapshot succeeded")
                    self?.viewModel.mapSnapshot = snapshot
                    let bounds = NSRect(origin: .zero, size: snapshot.image.size)
                    let annotatedImage = self?.drawAirports(on: snapshot, bounds: bounds) ?? snapshot.image
                    self?.viewModel.backgroundImage = annotatedImage
                }
            }
        }
    }

    private func drawAirports(on snapshot: MKMapSnapshotter.Snapshot, bounds: NSRect) -> NSImage {
        let baseImage = snapshot.image
        let newImage = NSImage(size: baseImage.size)

        newImage.lockFocus()
        baseImage.draw(in: NSRect(origin: .zero, size: baseImage.size))

        let activeAirports = AirportDatabase.shared.projectedAirports(in: snapshot, bounds: bounds)

        for airport in activeAirports {
            let drawPoint = airport.point

            // Draw marker circle
            let markerSize: CGFloat = 20.0
            let markerRect = NSRect(
                x: drawPoint.x - markerSize / 2,
                y: drawPoint.y - markerSize / 2,
                width: markerSize,
                height: markerSize
            )

            let path = NSBezierPath(ovalIn: markerRect)
            // Premium light blue airport color
            NSColor(red: 0.18, green: 0.58, blue: 0.95, alpha: 0.9).setFill()
            path.fill()

            // Draw a subtle border
            NSColor.white.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 1.5
            path.stroke()

            // Draw airplane symbol inside
            if let airplane = NSImage(systemSymbolName: "airplane", accessibilityDescription: nil) {
                let tintedAirplane = airplane.tinted(with: .white)
                let iconSize: CGFloat = 12.0
                let iconRect = NSRect(
                    x: drawPoint.x - iconSize / 2,
                    y: drawPoint.y - iconSize / 2,
                    width: iconSize,
                    height: iconSize
                )
                tintedAirplane.draw(in: iconRect)
            }

            // Draw airport name and code (e.g. "Sydney (YSSY)")
            let text = "\(airport.name) (\(airport.code))"
            let font = NSFont.systemFont(ofSize: 11, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .shadow: {
                    let s = NSShadow()
                    s.shadowColor = NSColor.black
                    s.shadowOffset = NSSize(width: 0, height: -1)
                    s.shadowBlurRadius = 2.0
                    return s
                }()
            ]

            let size = text.size(withAttributes: attributes)
            let textPoint = NSPoint(
                x: drawPoint.x - size.width / 2,
                y: drawPoint.y - markerSize / 2 - size.height - 4
            )

            // Draw a tiny dark background capsule for the text to ensure legibility over any map terrain
            let bgRect = NSRect(
                x: textPoint.x - 4,
                y: textPoint.y - 2,
                width: size.width + 8,
                height: size.height + 4
            )
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
            NSColor.black.withAlphaComponent(0.6).setFill()
            bgPath.fill()

            text.draw(at: textPoint, withAttributes: attributes)
        }

        newImage.unlockFocus()
        return newImage
    }

    public func render(state: ScreensaverState) {
        viewModel.state = state
    }

    public override func draw(_ rect: NSRect) {
        // No-op: Drawing is handled entirely by layer-backed subviews
    }

    public override func animateOneFrame() {
        // No-op: Disable legacy animation tick redrawing, letting SwiftUI and MapKit manage frames
    }

    // Map delegation and renderer now handled natively by SwiftUI BackgroundMapView coordinator

    private func startRefreshLoopIfNeeded() {
        guard refreshTimer == nil || (previewMode && rotationTimer == nil) else { return }

        if previewMode {
            screensaverLogger.info("showing preview data")
            showPreviewData()
        } else {
            screensaverLogger.info("requesting flights immediately")
            requestFlights()
            
            let timer = Timer(timeInterval: 8, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.requestFlights()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }

        if rotationTimer == nil {
            let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.advanceCard()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            rotationTimer = timer
        }
    }

    private func requestFlights() {
        requestSequence += 1
        let requestID = requestSequence
        let isRefreshingLiveContent = isShowingLiveContent

        activeDataTask?.cancel()
        loadingWatchdog?.cancel()
        loadingWatchdog = nil

        let url: URL
        do {
            url = try FlightFeedRequest.flightsURL(
                baseURL: flightFeedClient.baseURL,
                homeLatitude: flightFeedClient.homeLatitude,
                homeLongitude: flightFeedClient.homeLongitude,
                radiusNm: flightFeedClient.radiusNm
            )
            screensaverLogger.info("fetching flights url=\(url.absoluteString, privacy: .public)")
        } catch {
            screensaverLogger.error("failed to build flights url")
            if !isRefreshingLiveContent {
                viewModel.state = .offline(message: "Unable to load aircraft data")
            }
            return
        }

        activeDataTask = flightFeedClient.session.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.requestSequence == requestID else { return }
                self.loadingWatchdog?.cancel()
                self.loadingWatchdog = nil

                if let urlError = error as? URLError, urlError.code == .cancelled {
                    return
                }

                if let error {
                    screensaverLogger.error("request failed error=\(error.localizedDescription, privacy: .public)")
                    if !isRefreshingLiveContent {
                        self.viewModel.state = .offline(message: error.localizedDescription)
                    } else {
                        screensaverLogger.info("keeping existing live card after refresh failure")
                    }
                    return
                }

                guard let data else {
                    screensaverLogger.error("request completed without data")
                    if !isRefreshingLiveContent {
                        self.viewModel.state = .offline(message: "Unable to load aircraft data")
                    } else {
                        screensaverLogger.info("keeping existing live card after empty refresh response")
                    }
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(ProxyFlightResponse.self, from: data)
                    let flights = decoded.flights
                    screensaverLogger.info("request succeeded flights=\(flights.count, privacy: .public)")
                    self.currentFlights = flights
                    let maxDistanceKm = Double(self.flightFeedClient.radiusNm) * 1.852
                    let insideCircleFlights = flights.filter { $0.isInsideGeofence(radiusKm: maxDistanceKm) }
                    self.rotationController.update(flights: insideCircleFlights)
                    self.updateState(with: flights)
                } catch {
                    screensaverLogger.error("decode failed error=\(error.localizedDescription, privacy: .public)")
                    if !isRefreshingLiveContent {
                        self.viewModel.state = .offline(message: "Unable to load aircraft data")
                    } else {
                        screensaverLogger.info("keeping existing live card after decode failure")
                    }
                }
            }
        }

        activeDataTask?.resume()

        let watchdog = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.requestSequence == requestID else { return }
            guard self.viewModel.state == .loading else { return }
            screensaverLogger.info("loading watchdog expired")
            if !isRefreshingLiveContent {
                self.viewModel.state = .noFlights
            } else {
                screensaverLogger.info("keeping existing live card after refresh watchdog expiry")
            }
        }
        loadingWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: watchdog)
    }

    private var isShowingLiveContent: Bool {
        if case .live = viewModel.state {
            return true
        }
        return false
    }

    private func updateState(with flights: [Flight]) {
        viewModel.updateTrails(with: flights)

        guard let currentFlight = rotationController.currentFlight else {
            screensaverLogger.info("updateState no current flight total=\(flights.count, privacy: .public)")
            viewModel.state = .noFlights
            return
        }

        guard let index = flights.firstIndex(where: { $0.id == currentFlight.id }) else {
            screensaverLogger.info(
                "updateState current flight missing id=\(currentFlight.id, privacy: .public) total=\(flights.count, privacy: .public)"
            )
            viewModel.state = .noFlights
            return
        }

        screensaverLogger.info(
            "updateState showing card=\(index + 1, privacy: .public)/\(flights.count, privacy: .public) callsign=\(currentFlight.callsign, privacy: .public)"
        )
        viewModel.state = .live(flights, index: index)
    }

    private func advanceCard() {
        let maxDistanceKm = Double(self.flightFeedClient.radiusNm) * 1.852
        let insideCircleCount = self.currentFlights.filter { $0.distanceKm <= maxDistanceKm }.count
        guard insideCircleCount > 1 else {
            screensaverLogger.info("advanceCard skipped insideCircleCount=\(insideCircleCount, privacy: .public)")
            return
        }

        let previousFlight = self.rotationController.currentFlight
        self.rotationController.advance()
        if let currentFlight = self.rotationController.currentFlight {
            screensaverLogger.info(
                "advanceCard previous=\(previousFlight?.callsign ?? "nil", privacy: .public) current=\(currentFlight.callsign, privacy: .public) total=\(self.currentFlights.count, privacy: .public)"
            )
        } else {
            screensaverLogger.info("advanceCard current flight became nil total=\(self.currentFlights.count, privacy: .public)")
        }
        self.updateState(with: self.currentFlights)
    }

    private func showPreviewData() {
        let flights = [
            Flight(
                id: "preview-1",
                callsign: "QFA1",
                airline: "Qantas",
                aircraftType: "A332",
                registration: "VH-EBL",
                originCity: "Sydney",
                destinationCity: "Perth",
                altitudeFt: 36000,
                speedKt: 480,
                distanceKm: 2.4,
                phase: .cruising,
                squawk: nil
            ),
            Flight(
                id: "preview-2",
                callsign: "JQ42",
                airline: "Jetstar",
                aircraftType: "A320",
                registration: "VH-VQF",
                originCity: "Melbourne",
                destinationCity: "Gold Coast",
                altitudeFt: 12400,
                speedKt: 305,
                distanceKm: 4.8,
                phase: .descending,
                squawk: nil
            )
        ]

        let maxDistanceKm = Double(self.flightFeedClient.radiusNm) * 1.852
        let insideCircleFlights = flights.filter { $0.distanceKm <= maxDistanceKm }
        rotationController.update(flights: insideCircleFlights)
        currentFlights = flights
        updateState(with: flights)
    }
}

@MainActor
final class ScreensaverViewModel: ObservableObject {
    @Published var state: ScreensaverState = .loading
    @Published var backgroundImage: NSImage? = nil
    @Published var mapSnapshot: MKMapSnapshotter.Snapshot? = nil
    @Published var flightTrails: [String: [CLLocationCoordinate2D]] = [:]
    var homeLongitude: Double = FlightFeedClient.defaultHomeLongitude
    var geofenceRadiusKm: Double = Double(FlightFeedClient.defaultRadiusNm) * 1.852

    func updateTrails(with flights: [Flight]) {
        var newTrails: [String: [CLLocationCoordinate2D]] = [:]
        for flight in flights {
            guard let lat = flight.latitude, let lon = flight.longitude else { continue }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

            var existing = flightTrails[flight.id] ?? []
            if let last = existing.last, last.latitude == lat, last.longitude == lon {
                // No-op to avoid duplicates
            } else {
                existing.append(coord)
            }

            if existing.count > 30 {
                existing.removeFirst(existing.count - 30)
            }
            newTrails[flight.id] = existing
        }
        self.flightTrails = newTrails
    }

    func mapHeadingDegrees(for flight: Flight) -> Double {
        guard let trail = flightTrails[flight.id], trail.count >= 2,
              let previous = trail.dropLast().last,
              let current = trail.last else {
            return flight.mapHeadingDegrees
        }

        return Flight.bearingDegrees(
            fromLatitude: previous.latitude,
            longitude: previous.longitude,
            toLatitude: current.latitude,
            longitude: current.longitude
        )
    }
}

@MainActor
struct CardOverlayView: View {
    @ObservedObject var viewModel: ScreensaverViewModel

    var body: some View {
        switch viewModel.state {
        case .loading:
            LoadingStatusView()
        case .noFlights:
            NoFlightsStatusView()
        case .offline(let message):
            OfflineStatusView(message: message)
        case .live(let flights, let index):
            if flights.indices.contains(index) {
                let flight = flights[index]
                let alignToRight = (flight.longitude ?? 0.0) < viewModel.homeLongitude

                HStack {
                    if alignToRight {
                        Spacer()
                    }

                    FlightCardView(
                        flight: flight,
                        positionText: "\(index + 1) / \(flights.count)"
                    )
                    .padding(.horizontal, 80)

                    if !alignToRight {
                        Spacer()
                    }
                }
            } else {
                NoFlightsStatusView()
            }
        }
    }
}

struct MapSnapshotView: View {
    @ObservedObject var viewModel: ScreensaverViewModel

    var body: some View {
        GeometryReader { geometry in
            let minDimension = min(geometry.size.width, geometry.size.height)
            ZStack {
                if let bgImage = viewModel.backgroundImage {
                    Image(nsImage: bgImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black
                }

                // Draw circular geofence ring in the center of the screen
                Circle()
                    .stroke(Color.orange.opacity(0.35), lineWidth: 2)
                    .frame(width: minDimension * 0.72, height: minDimension * 0.72)

                if let mapSnapshot = viewModel.mapSnapshot {
                    let activeId: String? = {
                        if case .live(let flights, let index) = viewModel.state, flights.indices.contains(index) {
                            return flights[index].id
                        }
                        return nil
                    }()

                    // 1. Draw trailing paths in aviation yellow (same solid lines for all active flights)
                    ForEach(Array(viewModel.flightTrails.keys), id: \.self) { flightId in
                        if let trail = viewModel.flightTrails[flightId], trail.count > 1 {
                            Path { path in
                                let points = trail.map { mapSnapshot.point(for: $0) }
                                if let first = points.first {
                                    path.move(to: first)
                                    for point in points.dropFirst() {
                                        path.addLine(to: point)
                                    }
                                }
                            }
                            .stroke(
                                Color.yellow.opacity(0.65),
                                style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                            )
                        }
                    }

                    // 2. Draw anchor line from the featured plane to the card position (in white/grey).
                    if case .live(let flights, _) = viewModel.state,
                       let activeFlight = flights.first(where: {
                           $0.id == activeId && $0.isInsideGeofence(radiusKm: viewModel.geofenceRadiusKm)
                       }),
                       let lat = activeFlight.latitude, let lon = activeFlight.longitude {
                        let pt = mapSnapshot.point(for: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        let alignToRight = (activeFlight.longitude ?? 0.0) < viewModel.homeLongitude
                        let cardAnchorX = alignToRight ? (geometry.size.width - 80 - 240) : (80 + 240)
                        let cardAnchor = CGPoint(x: cardAnchorX, y: geometry.size.height / 2)

                        Path { path in
                            path.move(to: pt)
                            path.addLine(to: cardAnchor)
                        }
                        .stroke(
                            Color.white.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                    }

                    // Draw plane icons oriented to their actual motion when history exists.
                    if case .live(let flights, _) = viewModel.state {
                        ForEach(flights, id: \.id) { flight in
                            if let lat = flight.latitude, let lon = flight.longitude {
                                let pt = mapSnapshot.point(for: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                let isActive = flight.id == activeId && flight.isInsideGeofence(radiusKm: viewModel.geofenceRadiusKm)

                                ZStack {
                                    if isActive {
                                        Circle()
                                            .fill(Color.yellow.opacity(0.25))
                                            .frame(width: 32, height: 32)
                                    }

                                    Image(systemName: "airplane")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: isActive ? 22 : 16, height: isActive ? 22 : 16)
                                        .foregroundColor(Color.yellow)
                                        .rotationEffect(.degrees(viewModel.mapHeadingDegrees(for: flight)))
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                                    Text(flight.callsign)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.black.opacity(0.65))
                                        .cornerRadius(3)
                                        .offset(y: isActive ? -22 : -18)
                                }
                                .position(x: pt.x, y: pt.y)
                            }
                        }
                    }
                }

                // Home marker pin in the center
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 24, height: 24)
                    Text("H")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

@MainActor
struct OverheadTrackerScreensaverRootView: View {
    @ObservedObject var viewModel: ScreensaverViewModel

    var body: some View {
        ZStack {
            MapSnapshotView(viewModel: viewModel)
                .ignoresSafeArea()

            CardOverlayView(viewModel: viewModel)
        }
        .background(Color.clear)
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let tintedImage = NSImage(size: size)
        tintedImage.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        color.set()
        rect.fill(using: .sourceAtop)
        
        tintedImage.unlockFocus()
        return tintedImage
    }
}

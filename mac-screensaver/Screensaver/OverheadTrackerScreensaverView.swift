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
                if let image = snapshot?.image {
                    screensaverLogger.info("Map snapshot succeeded")
                    self?.viewModel.backgroundImage = image
                }
            }
        }
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
                    self.rotationController.update(flights: flights)
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
        guard self.currentFlights.count > 1 else {
            screensaverLogger.info("advanceCard skipped total=\(self.currentFlights.count, privacy: .public)")
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

        rotationController.update(flights: flights)
        currentFlights = flights
        updateState(with: flights)
    }
}

@MainActor
final class ScreensaverViewModel: ObservableObject {
    @Published var state: ScreensaverState = .loading
    @Published var backgroundImage: NSImage? = nil
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
                FlightCardView(
                    flight: flights[index],
                    positionText: "\(index + 1) / \(flights.count)"
                )
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

import AppKit
import Combine
import ScreenSaver
import OverheadTrackerScreensaverCore
import os
import SwiftUI

private let screensaverLogger = Logger(subsystem: "com.overheadtracker.screensaver", category: "screensaver")

@objc(OverheadTrackerScreensaverView)
@MainActor
public final class OverheadTrackerScreensaverView: ScreenSaverView {
    private let flightFeedClient = FlightFeedClient()
    private let rotationController = RotationController(flights: [])
    private let viewModel: ScreensaverViewModel
    private let hostingView: NSHostingView<OverheadTrackerScreensaverRootView>
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
        hostingView = NSHostingView(rootView: OverheadTrackerScreensaverRootView(viewModel: viewModel))
        super.init(frame: frame, isPreview: isPreview)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        animationTimeInterval = 1.0 / 30.0

        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

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
    }

    public func render(state: ScreensaverState) {
        viewModel.state = state
    }

    public override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }

    private func startRefreshLoopIfNeeded() {
        guard refreshTimer == nil else { return }

        if previewMode {
            screensaverLogger.info("showing preview data")
            showPreviewData()
            return
        }

        screensaverLogger.info("requesting flights immediately")
        requestFlights()
        
        let timer = Timer(timeInterval: 8, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.requestFlights()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        let rotationTimer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.advanceCard()
            }
        }
        RunLoop.main.add(rotationTimer, forMode: .common)
        self.rotationTimer = rotationTimer
    }

    private func requestFlights() {
        requestSequence += 1
        let requestID = requestSequence

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
            viewModel.state = .offline(message: "Unable to load aircraft data")
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
                    self.viewModel.state = .offline(message: error.localizedDescription)
                    return
                }

                guard let data else {
                    screensaverLogger.error("request completed without data")
                    self.viewModel.state = .offline(message: "Unable to load aircraft data")
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
                    self.viewModel.state = .offline(message: "Unable to load aircraft data")
                }
            }
        }

        activeDataTask?.resume()

        let watchdog = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.requestSequence == requestID else { return }
            guard self.viewModel.state == .loading else { return }
            screensaverLogger.info("loading watchdog expired")
            self.viewModel.state = .noFlights
        }
        loadingWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: watchdog)
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
}

@MainActor
struct OverheadTrackerScreensaverRootView: View {
    @ObservedObject var viewModel: ScreensaverViewModel

    var body: some View {
        Group {
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
}

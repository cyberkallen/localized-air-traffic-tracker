import AppKit
import ScreenSaver
import OverheadTrackerScreensaverCore
import SwiftUI

@MainActor
public final class OverheadTrackerScreensaverView: ScreenSaverView {
    private let hostingView: NSHostingView<OverheadTrackerScreensaverRootView>

    public override init?(frame: NSRect, isPreview: Bool) {
        hostingView = NSHostingView(rootView: OverheadTrackerScreensaverRootView())
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func render(state: ScreensaverState) {
        hostingView.rootView = OverheadTrackerScreensaverRootView(state: state)
    }

    public override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }
}

@MainActor
struct OverheadTrackerScreensaverRootView: View {
    let state: ScreensaverState

    init(state: ScreensaverState = .loading) {
        self.state = state
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                LoadingStatusView()
            case .noFlights:
                NoFlightsStatusView()
            case .offline(let message):
                OfflineStatusView(message: message)
            case .live(let flights, let index):
                if flights.indices.contains(index) {
                    FlightCardView(flight: flights[index])
                } else {
                    NoFlightsStatusView()
                }
            }
        }
    }
}

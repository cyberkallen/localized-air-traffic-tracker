import SwiftUI

struct StatusView: View {
    let title: String
    let detail: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(detail)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(48)
            .frame(maxWidth: 760)
        }
        .foregroundStyle(.white)
    }
}

struct LoadingStatusView: View {
    var body: some View {
        StatusView(title: "LOADING", detail: "Waiting for live aircraft data")
    }
}

struct NoFlightsStatusView: View {
    var body: some View {
        StatusView(title: "NO AIRCRAFT OVERHEAD", detail: "Nothing within range right now")
    }
}

struct OfflineStatusView: View {
    let message: String

    var body: some View {
        StatusView(title: "OFFLINE", detail: message)
    }
}

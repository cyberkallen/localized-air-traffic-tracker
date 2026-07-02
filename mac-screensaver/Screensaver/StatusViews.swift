import SwiftUI

struct StatusView: View {
    let title: String
    let detail: String

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(detail)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
            .frame(maxWidth: 600)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.48), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
            )
            .padding(48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

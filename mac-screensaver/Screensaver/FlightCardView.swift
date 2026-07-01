import Foundation
import OverheadTrackerScreensaverCore
import SwiftUI

struct FlightCardView: View {
    let flight: Flight

    private var accentColor: Color {
        if flight.isEmergency {
            return .red
        }

        switch flight.phase {
        case .landing, .takeoff:
            return .orange
        case .approach:
            return .yellow
        case .descending:
            return .cyan
        case .climbing:
            return .green
        case .cruising:
            return .teal
        case .overhead:
            return .white
        case .unknown:
            return .gray
        }
    }

    private var phaseLabel: String {
        flight.isEmergency ? "EMERGENCY" : flight.phase.rawValue.uppercased()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(flight.callsign)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(flight.airline)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))

                    Text("\(flight.originCity) to \(flight.destinationCity)")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(accentColor)
                }

                Text("\(flight.aircraftType)  \(flight.registration)")
                    .font(.system(size: 18, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(alignment: .top, spacing: 20) {
                    statView(title: "ALT", value: "\(flight.altitudeFt) FT")
                    statView(title: "SPD", value: "\(flight.speedKt) KT")
                    statView(title: "DST", value: String(format: "%.1f KM", flight.distanceKm))
                    statView(title: "PHASE", value: phaseLabel)
                }

                if flight.isEmergency {
                    Text("EMERGENCY SQUAWK")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.red, lineWidth: 1)
                        )
                }
            }
            .padding(48)
            .frame(maxWidth: 980, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.07, blue: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.72), lineWidth: 2)
                    )
                    .shadow(color: accentColor.opacity(0.22), radius: 24, x: 0, y: 10)
            )
            .padding(48)
            .foregroundStyle(.white)
        }
    }

    private func statView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accentColor)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
        }
        .frame(minWidth: 110, alignment: .leading)
    }
}

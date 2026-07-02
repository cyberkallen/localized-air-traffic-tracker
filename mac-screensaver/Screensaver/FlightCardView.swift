import AppKit
import Foundation
import OverheadTrackerScreensaverCore
import SwiftUI

@MainActor
struct FlightCardView: View {
    let flight: Flight
    let positionText: String?

    @State private var logoImage: NSImage?

    private var prefix: String {
        airlinePrefix(from: flight.callsign)
    }

    private var logoKey: String {
        "logo:\(prefix)"
    }

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
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(flight.callsign)
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        HStack(alignment: .center, spacing: 12) {
                            if let logoImage {
                                Image(nsImage: logoImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            }

                            Text(flight.airline)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                        }

                        Text("\(flight.originCity) to \(flight.destinationCity)")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundStyle(accentColor)
                    }

                    Spacer(minLength: 12)

                    FlightArtworkTileView(flight: flight, accentColor: accentColor)
                        .frame(width: 240, height: 172)
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
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.72), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 10)
                    .shadow(color: accentColor.opacity(0.18), radius: 12, x: 0, y: 4)
            )
            .padding(48)
            .foregroundStyle(.white)
            .overlay(alignment: .topTrailing) {
                if let positionText {
                    Text(positionText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.48))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.75), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(22)
                }
            }
        }
        .task(id: logoKey) {
            logoImage = nil
            guard !prefix.isEmpty else { return }

            if let cachedLogo = FlightImageCache.shared.image(for: logoKey) {
                logoImage = cachedLogo
            } else if let loadedLogo = await FlightArtworkFetcher.loadAirlineLogo(prefix: prefix) {
                logoImage = loadedLogo
                FlightImageCache.shared.store(loadedLogo, for: logoKey)
            }
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

@MainActor
private struct FlightArtworkTileView: View {
    let flight: Flight
    let accentColor: Color

    @State private var photoImage: NSImage?

    private var prefix: String {
        airlinePrefix(from: flight.callsign)
    }

    private var brandColor: Color {
        airlineBrandColor(for: prefix) ?? accentColor
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(brandColor.opacity(0.48), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)

            if let photoImage {
                Image(nsImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 172)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "airplane")
                        .font(.system(size: 40))
                        .foregroundStyle(brandColor.opacity(0.6))
                    Text("NO PHOTO")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(width: 240, height: 172, alignment: .center)
            }
        }
        .task(id: artworkKey) {
            photoImage = nil

            guard !artworkKey.isEmpty else {
                return
            }

            guard let photoKey else {
                return
            }

            if let cachedPhoto = FlightImageCache.shared.image(for: photoKey) {
                photoImage = cachedPhoto
            } else if let loadedPhoto = await FlightArtworkFetcher.loadAircraftPhoto(flight: flight) {
                photoImage = loadedPhoto
                FlightImageCache.shared.store(loadedPhoto, for: photoKey)
            }
        }
    }

    private var artworkKey: String {
        [
            flight.id,
            flight.callsign,
            prefix,
            flight.hex ?? "",
            flight.registration,
            flight.aircraftType
        ].joined(separator: "|")
    }

    private var photoKey: String? {
        let reg = flight.registration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reg.isEmpty && reg != "---" && reg != "Unknown" {
            return "photo:reg:\(reg.uppercased())"
        }
        guard let hex = flight.hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hex.isEmpty else {
            return nil
        }
        return "photo:hex:\(hex.uppercased())"
    }
}

@MainActor
private final class FlightImageCache {
    static let shared = FlightImageCache()
    private var images: [String: NSImage] = [:]

    func image(for key: String) -> NSImage? {
        images[key]
    }

    func store(_ image: NSImage, for key: String) {
        images[key] = image
    }
}

private enum FlightArtworkFetcher {
    static func loadAirlineLogo(prefix: String) async -> NSImage? {
        let code = prefix.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 2 else { return nil }
        guard let url = URL(string: "https://content.airhex.com/content/logos/airlines_\(code)_120_120_c.png?theme=dark") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("OverheadTrackerScreensaver/1.0 (+https://overheadtracker.com)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                return nil
            }
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    static func loadAircraftPhoto(flight: Flight) async -> NSImage? {
        let reg = flight.registration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reg.isEmpty && reg != "---" && reg != "Unknown" {
            if let image = await fetchPhoto(from: "https://api.planespotters.net/pub/photos/reg/\(reg)") {
                return image
            }
        }

        if let hex = flight.hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty {
            if let image = await fetchPhoto(from: "https://api.planespotters.net/pub/photos/hex/\(hex)") {
                return image
            }
        }

        return nil
    }

    private static func fetchPhoto(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("OverheadTrackerScreensaver/1.0 (+https://overheadtracker.com)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                return nil
            }
            
            let decoded = try JSONDecoder().decode(PlanespottersPhotoResponse.self, from: data)
            guard let photoURL = decoded.bestPhotoURL else { return nil }

            let cacheKey = photoURL.absoluteString
            if let cached = await FlightImageCache.shared.image(for: cacheKey) {
                return cached
            }

            var photoRequest = URLRequest(url: photoURL)
            photoRequest.setValue("OverheadTrackerScreensaver/1.0 (+https://overheadtracker.com)", forHTTPHeaderField: "User-Agent")

            let (photoData, photoResponse) = try await URLSession.shared.data(for: photoRequest)
            if let httpPhotoResponse = photoResponse as? HTTPURLResponse, !(200...299).contains(httpPhotoResponse.statusCode) {
                return nil
            }
            
            guard let image = NSImage(data: photoData) else { return nil }
            await FlightImageCache.shared.store(image, for: cacheKey)
            return image
        } catch {
            return nil
        }
    }
}

private struct PlanespottersPhotoResponse: Decodable {
    let photos: [PlanespottersPhoto]

    var bestPhotoURL: URL? {
        photos.first?.bestThumbnailURL
    }
}

private struct PlanespottersPhoto: Decodable {
    let thumbnailLarge: PlanespottersPhotoThumbnail?
    let thumbnail: PlanespottersPhotoThumbnail?

    enum CodingKeys: String, CodingKey {
        case thumbnailLarge = "thumbnail_large"
        case thumbnail
    }

    var bestThumbnailURL: URL? {
        thumbnailLarge?.src ?? thumbnail?.src
    }
}

private struct PlanespottersPhotoThumbnail: Decodable {
    let src: URL?
}

private func airlinePrefix(from callsign: String) -> String {
    let prefix = callsign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return prefix.split(whereSeparator: { !$0.isLetter }).first.map(String.init) ?? ""
}

private func airlineBrandColor(for prefix: String) -> Color? {
    switch prefix.uppercased() {
    case "QFA", "QLK", "JAL", "JST", "CCA", "QXE", "BAW", "AFR":
        return Color(red: 1.0, green: 0.125, blue: 0.129)
    case "VOZ", "MAS", "QTR", "THY", "VJC", "CRK", "DAL", "PDT", "PSA":
        return Color(red: 1.0, green: 0.271, blue: 0.549)
    case "RXA", "FJI", "ANZ", "SIA", "TGW", "ANG", "WJA", "UPS":
        return Color(red: 0.129, green: 0.875, blue: 0.259)
    case "UAE", "ETD", "DLH", "AIC", "FRE", "HND", "NKS":
        return Color(red: 1.0, green: 0.835, blue: 0.0)
    case "THA", "PAL", "EVA", "ASA", "JBU", "SWA", "AAL", "UAL", "FDM":
        return Color(red: 0.259, green: 0.667, blue: 1.0)
    case "CPA", "CSN", "CES", "KAL", "AAR", "ACA", "CAV", "SKW", "RPA", "EDV", "GJS", "SCX", "MES", "VOI":
        return Color(red: 0.647, green: 0.396, blue: 1.0)
    case "HAL", "LAN", "CHH", "CXA", "CEB", "FDX", "GTI", "CLX", "DHK", "TAY", "NJT", "PEL", "UTY":
        return Color(red: 1.0, green: 0.647, blue: 0.0)
    default:
        return nil
    }
}

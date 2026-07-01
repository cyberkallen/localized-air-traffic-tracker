import AppKit
import Foundation
import OverheadTrackerScreensaverCore
import SwiftUI

@MainActor
struct FlightCardView: View {
    let flight: Flight
    let positionText: String?

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
                HStack(alignment: .top, spacing: 24) {
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
                    .fill(Color(red: 0.06, green: 0.07, blue: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.72), lineWidth: 2)
                    )
                    .shadow(color: accentColor.opacity(0.22), radius: 24, x: 0, y: 10)
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

    @State private var logoImage: NSImage?
    @State private var photoImage: NSImage?

    private var prefix: String {
        airlinePrefix(from: flight.callsign)
    }

    private var brandColor: Color {
        airlineBrandColor(for: prefix) ?? accentColor
    }

    private var photoCaption: String {
        [flight.aircraftType, flight.registration]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .black.opacity(0.08),
                                        .black.opacity(0.42)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AIRCRAFT PHOTO")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(brandColor)
                    Text(photoCaption.isEmpty ? "WAITING FOR IMAGE" : photoCaption)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    Text(flight.hex?.uppercased() ?? "NO HEX")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(14)
                .frame(width: 240, height: 172, alignment: .leading)
            }

            VStack(alignment: .trailing, spacing: 6) {
                if let logoImage {
                    Image(nsImage: logoImage)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .frame(width: 68, height: 68)
                        .background(Color.black.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(brandColor.opacity(0.8), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VStack(spacing: 4) {
                        Text(prefix.isEmpty ? "AIR" : prefix)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(flight.airline)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(brandColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minWidth: 68, minHeight: 68)
                    .background(Color.black.opacity(0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(brandColor.opacity(0.8), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(10)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 56)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flight.aircraftType)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(flight.registration)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
        }
        .task(id: artworkKey) {
            guard !artworkKey.isEmpty else {
                logoImage = nil
                photoImage = nil
                return
            }

            if let cachedLogo = FlightImageCache.shared.image(for: logoKey) {
                logoImage = cachedLogo
            } else if let loadedLogo = await FlightArtworkFetcher.loadAirlineLogo(prefix: prefix) {
                logoImage = loadedLogo
                FlightImageCache.shared.store(loadedLogo, for: logoKey)
            }

            guard let photoKey else {
                photoImage = nil
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

    private var logoKey: String {
        "logo:\(prefix)"
    }

    private var photoKey: String? {
        guard let hex = flight.hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hex.isEmpty else {
            return nil
        }

        return "photo:\(hex.uppercased()):\(flight.registration.uppercased()):\(flight.aircraftType.uppercased())"
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
        guard let url = airlineLogoURL(for: prefix) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    static func loadAircraftPhoto(flight: Flight) async -> NSImage? {
        guard let url = aircraftPhotoLookupURL(for: flight) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PlanespottersPhotoResponse.self, from: data)
            guard let photoURL = response.bestPhotoURL else { return nil }

            let cacheKey = photoURL.absoluteString
            if let cached = await FlightImageCache.shared.image(for: cacheKey) {
                return cached
            }

            let (photoData, _) = try await URLSession.shared.data(from: photoURL)
            guard let image = NSImage(data: photoData) else { return nil }
            await FlightImageCache.shared.store(image, for: cacheKey)
            return image
        } catch {
            return nil
        }
    }

    private static func airlineLogoURL(for prefix: String) -> URL? {
        let code = prefix.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 2 else { return nil }
        return URL(string: "https://content.airhex.com/content/logos/airlines_\(code)_120_120_c.png?theme=dark")
    }

    private static func aircraftPhotoLookupURL(for flight: Flight) -> URL? {
        guard let hex = flight.hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hex.isEmpty else { return nil }

        var components = URLComponents(string: "https://api.planespotters.net/pub/photos/hex/\(hex)")!
        var queryItems: [URLQueryItem] = []

        let reg = flight.registration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reg.isEmpty && reg != "---" {
            queryItems.append(URLQueryItem(name: "reg", value: reg))
        }

        let type = flight.aircraftType.trimmingCharacters(in: .whitespacesAndNewlines)
        if !type.isEmpty && type != "---" {
            queryItems.append(URLQueryItem(name: "icaoType", value: type))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
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

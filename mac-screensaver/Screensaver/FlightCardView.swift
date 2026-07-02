import AppKit
import Foundation
import MapKit
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

                            let airlineText: String = {
                                if let resolved = lookupAirlineName(for: prefix) {
                                    return resolved
                                }
                                let raw = flight.airline.trimmingCharacters(in: .whitespacesAndNewlines)
                                if raw == "Unknown" || raw.isEmpty {
                                    return "Private Operator"
                                }
                                return raw
                            }()
                            Text(airlineText)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                        }

                        let routeText: String = {
                            let origin = flight.originCity
                            let destination = flight.destinationCity
                            let hasOrigin = origin != "Unknown" && !origin.isEmpty
                            let hasDestination = destination != "Unknown" && !destination.isEmpty
                            
                            func formatAirport(_ code: String) -> String {
                                let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                if let name = AirportDatabase.shared.airportName(for: cleaned) {
                                    return "\(name) (\(cleaned))"
                                }
                                return cleaned
                            }
                            
                            if !hasOrigin && !hasDestination {
                                return "Local / Untracked Route"
                            } else if hasOrigin && !hasDestination {
                                return "Departing \(formatAirport(origin))"
                            } else if !hasOrigin && hasDestination {
                                return "Arriving at \(formatAirport(destination))"
                            } else {
                                return "\(formatAirport(origin)) to \(formatAirport(destination))"
                            }
                        }()

                        Text(routeText)
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

        // 1. Try custom github repository first (cyberkallen/airline-logos)
        if let githubURL = URL(string: "https://raw.githubusercontent.com/cyberkallen/airline-logos/main/logos/\(code).png") {
            var request = URLRequest(url: githubURL)
            request.setValue("OverheadTrackerScreensaver/1.0 (+https://overheadtracker.com)", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
               let image = NSImage(data: data) {
                return image
            }
        }

        // 2. Fall back to airhex.com
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

private func lookupAirlineName(for prefix: String) -> String? {
    switch prefix.uppercased() {
    case "QLK": return "QantasLink"
    case "QFA": return "Qantas"
    case "VOZ": return "Virgin Australia"
    case "JST": return "Jetstar"
    case "RXA": return "Regional Express"
    case "NZM": return "Air New Zealand Link"
    case "ANZ": return "Air New Zealand"
    case "SIA": return "Singapore Airlines"
    case "QTR": return "Qatar Airways"
    case "UAE": return "Emirates"
    case "ETD": return "Etihad Airways"
    case "FJI": return "Fiji Airways"
    case "ANG": return "Air Niugini"
    case "TGW": return "Scoot"
    case "MAS": return "Malaysia Airlines"
    case "THY": return "Turkish Airlines"
    case "VJC": return "VietJet Air"
    case "PAL": return "Philippine Airlines"
    case "EVA": return "EVA Air"
    case "CPA": return "Cathay Pacific"
    case "CSN": return "China Southern"
    case "CES": return "China Eastern"
    case "CCA": return "Air China"
    case "FDX": return "FedEx"
    case "UPS": return "UPS Airlines"
    case "PEL": return "Pel-Air"
    case "UTY": return "Alliance Airlines"
    default: return nil
    }
}

private let defaultAirports: [String: String] = [
    // Australia — major
    "YSSY": "Sydney", "YSAY": "Sydney", "YMLB": "Melbourne", "YMML": "Melbourne", "YBBN": "Brisbane",
    "YPPH": "Perth", "YPAD": "Adelaide", "YSCB": "Canberra", "YBCS": "Cairns", "YBHM": "Hamilton Is",
    "YBTL": "Townsville", "YBAS": "Alice Springs", "YBDG": "Bendigo", "YDBY": "Derby",
    "YSNF": "Norfolk Is", "YAGD": "Aganda", "YMHB": "Hobart", "YMLT": "Launceston",
    "SYD": "Sydney", "MEL": "Melbourne", "BNE": "Brisbane", "PER": "Perth", "ADL": "Adelaide",
    "CBR": "Canberra", "CNS": "Cairns", "OOL": "Gold Coast", "TSV": "Townsville", "DRW": "Darwin",
    "HBA": "Hobart", "LST": "Launceston", "MKY": "Mackay", "ROK": "Rockhampton",
    // Australia — NSW regional
    "YWLM": "Newcastle", "NTL": "Newcastle",
    "YBNA": "Ballina", "BNK": "Ballina",
    "YCFS": "Coffs Harbour", "CFS": "Coffs Harbour",
    "YPMQ": "Port Macquarie", "PQQ": "Port Macquarie",
    "YSDU": "Dubbo", "DBO": "Dubbo",
    "YSWG": "Wagga Wagga", "WGA": "Wagga Wagga",
    "YSTW": "Tamworth", "TMW": "Tamworth",
    "YARM": "Armidale", "ARM": "Armidale",
    "YORG": "Orange", "OAG": "Orange",
    "YMRY": "Moruya", "MYA": "Moruya",
    "YMER": "Merimbula", "MIM": "Merimbula",
    "YBHI": "Broken Hill", "BHQ": "Broken Hill",
    "YLHI": "Lord Howe Is", "LDH": "Lord Howe Is",
    "YGTH": "Griffith", "GFF": "Griffith",
    "YLIS": "Lismore", "LSY": "Lismore",
    "YDPO": "Devonport", "DPO": "Devonport",
    // International
    "NZAA": "Auckland", "NZCH": "Christchurch", "NZWN": "Wellington", "NZQN": "Queenstown",
    "AKL": "Auckland", "CHC": "Christchurch", "WLG": "Wellington", "ZQN": "Queenstown",
    "WSSS": "Singapore", "WSAP": "Singapore", "SIN": "Singapore",
    "VHHH": "Hong Kong", "HKG": "Hong Kong",
    "RJAA": "Tokyo", "RJTT": "Tokyo", "NRT": "Tokyo", "HND": "Tokyo",
    "RJBB": "Osaka", "RJOO": "Osaka", "KIX": "Osaka", "ITM": "Osaka",
    "RKSI": "Seoul", "RKSS": "Seoul", "ICN": "Seoul", "GMP": "Seoul",
    "RCTP": "Taipei", "RCSS": "Taipei", "TPE": "Taipei", "TSA": "Taipei",
    "VTBS": "Bangkok", "VTBD": "Bangkok", "BKK": "Bangkok", "DMK": "Bangkok",
    "WMKK": "Kuala Lumpur", "KUL": "Kuala Lumpur",
    "WADD": "Bali", "WIII": "Jakarta", "DPS": "Bali", "CGK": "Jakarta",
    "VMMC": "Macau", "MFM": "Macau",
    "VVTS": "Ho Chi Minh City", "SGN": "Ho Chi Minh City",
    "VVNB": "Hanoi", "HAN": "Hanoi",
    "VTCC": "Chiang Mai", "CNX": "Chiang Mai",
    "VTSP": "Phuket", "HKT": "Phuket",
    "RPLL": "Manila", "MNL": "Manila",
    "VDPP": "Phnom Penh", "PNH": "Phnom Penh",
    "VDSR": "Siem Reap", "REP": "Siem Reap",
    "KLAX": "Los Angeles", "LAX": "Los Angeles",
    "KSFO": "San Francisco", "SFO": "San Francisco",
    "KJFK": "New York", "JFK": "New York",
    "KEWR": "Newark", "EWR": "Newark",
    "KORD": "Chicago", "ORD": "Chicago",
    "KDFW": "Dallas", "DFW": "Dallas",
    "KIAH": "Houston", "IAH": "Houston",
    "KMIA": "Miami", "MIA": "Miami",
    "EGLL": "London", "EGKK": "London", "EGSS": "London", "EGLC": "London",
    "LHR": "London", "LGW": "London", "STN": "London", "LCY": "London", "LTN": "London",
    "LFPG": "Paris", "LFPO": "Paris", "CDG": "Paris", "ORY": "Paris",
    "EHAM": "Amsterdam", "AMS": "Amsterdam",
    "EDDF": "Frankfurt", "FRA": "Frankfurt",
    "EDDM": "Munich", "MUC": "Munich",
    "LEMD": "Madrid", "MAD": "Madrid",
    "LEBL": "Barcelona", "BCN": "Barcelona",
    "LIRF": "Rome", "LIMC": "Milan", "FCO": "Rome", "MXP": "Milan", "LIN": "Milan",
    "EGPH": "Edinburgh", "EGPF": "Glasgow", "EDI": "Edinburgh", "GLA": "Glasgow",
    "EIDW": "Dublin", "DUB": "Dublin",
    "EBBR": "Brussels", "BRU": "Brussels",
    "EKCH": "Copenhagen", "CPH": "Copenhagen",
    "ESSA": "Stockholm", "ARN": "Stockholm",
    "ENGM": "Oslo", "OSL": "Oslo",
    "EFHK": "Helsinki", "HEL": "Helsinki",
    "LSZH": "Zurich", "ZRH": "Zurich",
    "LSGG": "Geneva", "GVA": "Geneva",
    "LOWW": "Vienna", "VIE": "Vienna",
    "EPWA": "Warsaw", "WAW": "Warsaw",
    "LKPR": "Prague", "PRG": "Prague",
    "LHBP": "Budapest", "BUD": "Budapest",
    "LGAV": "Athens", "ATH": "Athens",
    "LTFM": "Istanbul", "LTBA": "Istanbul", "IST": "Istanbul", "SAW": "Istanbul",
]

struct AirportInfo: Codable {
    let iata: String
    let icao: String
    let name: String
    let latitude: Double
    let longitude: Double
}

private let defaultAirportsWithCoordinates: [AirportInfo] = [
    AirportInfo(iata: "SYD", icao: "YSSY", name: "Sydney", latitude: -33.9461, longitude: 151.177),
    AirportInfo(iata: "MEL", icao: "YMML", name: "Melbourne", latitude: -37.6733, longitude: 144.843),
    AirportInfo(iata: "BNE", icao: "YBBN", name: "Brisbane", latitude: -27.3842, longitude: 153.117),
    AirportInfo(iata: "PER", icao: "YPPH", name: "Perth", latitude: -31.9403, longitude: 115.967),
    AirportInfo(iata: "ADL", icao: "YPAD", name: "Adelaide", latitude: -34.945, longitude: 138.531),
    AirportInfo(iata: "CBR", icao: "YSCB", name: "Canberra", latitude: -35.3069, longitude: 149.195),
    AirportInfo(iata: "CNS", icao: "YBCS", name: "Cairns", latitude: -16.8858, longitude: 145.755),
    AirportInfo(iata: "OOL", icao: "YBCG", name: "Gold Coast", latitude: -28.1644, longitude: 153.505),
    AirportInfo(iata: "TSV", icao: "YBTL", name: "Townsville", latitude: -19.2525, longitude: 146.765),
    AirportInfo(iata: "DRW", icao: "YPDN", name: "Darwin", latitude: -12.4147, longitude: 130.877),
    AirportInfo(iata: "HBA", icao: "YMHB", name: "Hobart", latitude: -42.8361, longitude: 147.51),
    AirportInfo(iata: "LST", icao: "YMLT", name: "Launceston", latitude: -41.5456, longitude: 147.214),
]

class AirportDatabase {
    static let shared = AirportDatabase()

    private var lookupTable: [String: String] = [:]
    private var airportsList: [AirportInfo] = []
    private let lock = NSLock()

    private init() {
        loadCachedData()
        Task {
            await fetchIfNeeded()
        }
    }

    func airportName(for code: String) -> String? {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return lookupTable[cleaned]
    }

    struct ProjectedAirport {
        let name: String
        let code: String
        let point: NSPoint
    }

    // Projects coordinates using MapKit snapshot instance to check bounding box
    func projectedAirports(in snapshot: AnyObject, bounds: NSRect) -> [ProjectedAirport] {
        lock.lock()
        let list = airportsList
        lock.unlock()

        guard let mapSnapshot = snapshot as? MKMapSnapshotter.Snapshot else { return [] }

        var result: [ProjectedAirport] = []
        for airport in list {
            let coord = CLLocationCoordinate2D(latitude: airport.latitude, longitude: airport.longitude)
            let point = mapSnapshot.point(for: coord)
            if bounds.contains(point) {
                let code = !airport.icao.isEmpty ? airport.icao : airport.iata
                result.append(ProjectedAirport(name: airport.name, code: code, point: point))
            }
        }
        return result
    }

    private var cacheFileURL: URL? {
        let fileManager = FileManager.default
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let appCacheDir = cachesDir.appendingPathComponent("com.overheadtracker.screensaver", isDirectory: true)
        try? fileManager.createDirectory(at: appCacheDir, withIntermediateDirectories: true, attributes: nil)
        return appCacheDir.appendingPathComponent("airports_cache_v2.json")
    }

    private func loadCachedData() {
        lock.lock()
        defer { lock.unlock() }

        guard let url = cacheFileURL,
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([AirportInfo].self, from: data) else {
            self.lookupTable = defaultAirports
            self.airportsList = defaultAirportsWithCoordinates
            return
        }
        self.airportsList = list
        
        var dict: [String: String] = [:]
        for airport in list {
            if !airport.iata.isEmpty {
                dict[airport.iata] = airport.name
            }
            if !airport.icao.isEmpty {
                dict[airport.icao] = airport.name
            }
        }
        self.lookupTable = dict
    }

    private func fetchIfNeeded() async {
        if let url = cacheFileURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modificationDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) < 14 * 24 * 3600 {
            return
        }

        guard let downloadURL = URL(string: "https://raw.githubusercontent.com/cyberkallen/ip2location-iata-icao/master/iata-icao.csv") else { return }

        var request = URLRequest(url: downloadURL)
        request.setValue("OverheadTrackerScreensaver/1.0 (+https://overheadtracker.com)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let csvString = String(data: data, encoding: .utf8) else {
            return
        }

        let lines = csvString.components(separatedBy: .newlines)
        var list: [AirportInfo] = []
        var dict: [String: String] = [:]

        for line in lines {
            let cols = parseCSVRow(line)
            guard cols.count >= 7 else { continue }

            let iata = cols[2].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let icao = cols[3].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let airportRaw = cols[4]
            let latRaw = cols[5]
            let lonRaw = cols[6]

            guard let latitude = Double(latRaw),
                  let longitude = Double(lonRaw) else {
                continue
            }

            let cleanName = cleanAirportName(airportRaw)
            guard !cleanName.isEmpty else { continue }

            let info = AirportInfo(iata: iata, icao: icao, name: cleanName, latitude: latitude, longitude: longitude)
            list.append(info)

            if !iata.isEmpty && iata != "IATA" {
                dict[iata] = cleanName
            }
            if !icao.isEmpty && icao != "ICAO" {
                dict[icao] = cleanName
            }
        }

        if !list.isEmpty {
            lock.lock()
            self.airportsList = list
            self.lookupTable = dict
            lock.unlock()

            if let url = cacheFileURL,
               let jsonData = try? JSONEncoder().encode(list) {
                try? jsonData.write(to: url)
            }
        }
    }

    private func cleanAirportName(_ rawName: String) -> String {
        var name = rawName
        if let range = name.range(of: "\\s*\\([^)]*\\)", options: .regularExpression) {
            name.removeSubrange(range)
        }
        let suffixes = [" International Airport", " Regional Airport", " Airport", " Intl Airport"]
        for suffix in suffixes {
            if name.lowercased().hasSuffix(suffix.lowercased()) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        let chars = Array(row)
        var i = 0
        while i < chars.count {
            let char = chars[i]
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
            i += 1
        }
        result.append(current)
        return result
    }
}

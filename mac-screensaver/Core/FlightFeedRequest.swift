import Foundation

public enum FlightFeedRequest {
    public static func flightsURL(
        baseURL: URL,
        homeLatitude: Double,
        homeLongitude: Double,
        radiusNm: Int
    ) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.path = components.path.appending("/flights")
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(homeLatitude)),
            URLQueryItem(name: "lon", value: String(homeLongitude)),
            URLQueryItem(name: "radius", value: String(radiusNm))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }
}

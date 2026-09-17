import Foundation

struct SensorReading: Sendable {
    let state: String
    let unit: String?
}

struct SensorSnapshot: Sendable {
    var temperature: SensorReading?
    var humidity: SensorReading?
    var error: String?
    var updated: Date?
}

enum HAError: Error {
    case badURL
    case http(Int)
    case decode
}

struct HAClient: Sendable {
    private let baseURL: URL
    private let token: String

    init?(config: AppConfig) {
        guard let url = URL(string: config.baseURL) else { return nil }
        baseURL = url
        token = config.token
    }

    func fetch(entityId: String) async throws -> SensorReading {
        guard !entityId.isEmpty else { throw HAError.badURL }
        let url = baseURL
            .appendingPathComponent("api/states")
            .appendingPathComponent(entityId)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HAError.decode }
        guard (200..<300).contains(http.statusCode) else { throw HAError.http(http.statusCode) }
        let decoded = try JSONDecoder().decode(StateResponse.self, from: data)
        return SensorReading(state: decoded.state, unit: decoded.attributes?.unit_of_measurement)
    }

    func snapshot(for sensor: SensorConfig) async -> SensorSnapshot {
        do {
            async let temperature = fetch(entityId: sensor.temperatureEntity)
            async let humidity = fetch(entityId: sensor.humidityEntity)
            let (t, h) = try await (temperature, humidity)
            return SensorSnapshot(temperature: t, humidity: h, error: nil, updated: Date())
        } catch {
            return SensorSnapshot(temperature: nil, humidity: nil, error: Format.shortError(error), updated: Date())
        }
    }
}

private struct StateResponse: Decodable {
    let state: String
    let attributes: Attributes?

    struct Attributes: Decodable {
        let unit_of_measurement: String?
    }
}

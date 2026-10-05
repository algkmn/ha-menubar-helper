import Foundation

struct SensorConfig: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var temperatureEntity: String
    var humidityEntity: String
    var showInMenuBar: Bool
    var icon: String

    static let defaultIcon = "thermometer.medium"

    init(
        id: UUID = UUID(),
        name: String,
        temperatureEntity: String,
        humidityEntity: String,
        showInMenuBar: Bool = true,
        icon: String = SensorConfig.defaultIcon
    ) {
        self.id = id
        self.name = name
        self.temperatureEntity = temperatureEntity
        self.humidityEntity = humidityEntity
        self.showInMenuBar = showInMenuBar
        self.icon = icon
    }

    enum CodingKeys: String, CodingKey {
        case id, name, temperatureEntity, humidityEntity, showInMenuBar, icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        temperatureEntity = try container.decodeIfPresent(String.self, forKey: .temperatureEntity) ?? ""
        humidityEntity = try container.decodeIfPresent(String.self, forKey: .humidityEntity) ?? ""
        showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        name = decodedName.isEmpty ? SensorConfig.derivedName(from: temperatureEntity) : decodedName
        let decodedIcon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        icon = decodedIcon.isEmpty ? SensorConfig.defaultIcon : decodedIcon
    }

    var isUsable: Bool {
        !temperatureEntity.isEmpty && !humidityEntity.isEmpty
    }

    static func derivedName(from entityId: String) -> String {
        var slug = entityId
        if let dot = slug.firstIndex(of: ".") {
            slug = String(slug[slug.index(after: dot)...])
        }
        for suffix in ["_temperature", "_humidity", "_temp", "_sicaklik", "_nem"] where slug.hasSuffix(suffix) {
            slug = String(slug.dropLast(suffix.count))
            break
        }
        let words = slug.split(separator: "_").map { String($0).capitalized }
        return words.isEmpty ? "Sensör" : words.joined(separator: " ")
    }
}

struct AppConfig: Codable, Sendable {
    var baseURL: String
    var token: String
    var pollInterval: Double?
    var sensors: [SensorConfig]

    static let placeholderToken = "PASTE_LONG_LIVED_TOKEN"
    static let defaultPollInterval: Double = 15

    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/ha-menubar", isDirectory: true)
    static let fileURL = directory.appendingPathComponent("config.json")

    init(baseURL: String, token: String, pollInterval: Double?, sensors: [SensorConfig]) {
        self.baseURL = baseURL
        self.token = token
        self.pollInterval = pollInterval
        self.sensors = sensors
    }

    enum CodingKeys: String, CodingKey {
        case baseURL, token, pollInterval, sensors
        case temperatureEntity, humidityEntity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        pollInterval = try container.decodeIfPresent(Double.self, forKey: .pollInterval)
        let decoded = try container.decodeIfPresent([SensorConfig].self, forKey: .sensors) ?? []
        if decoded.isEmpty {
            let temperature = try container.decodeIfPresent(String.self, forKey: .temperatureEntity) ?? ""
            let humidity = try container.decodeIfPresent(String.self, forKey: .humidityEntity) ?? ""
            sensors = temperature.isEmpty && humidity.isEmpty
                ? []
                : [SensorConfig(
                    name: SensorConfig.derivedName(from: temperature),
                    temperatureEntity: temperature,
                    humidityEntity: humidity
                )]
        } else {
            sensors = decoded
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(token, forKey: .token)
        try container.encodeIfPresent(pollInterval, forKey: .pollInterval)
        try container.encode(sensors, forKey: .sensors)
    }

    var isUsable: Bool {
        !token.isEmpty && token != AppConfig.placeholderToken && !baseURL.isEmpty
            && URL(string: baseURL) != nil && sensors.contains(where: { $0.isUsable })
    }

    var menuBarSensors: [SensorConfig] {
        sensors.filter { $0.showInMenuBar && $0.isUsable }
    }

    var resolvedPollInterval: Double {
        guard let pollInterval, pollInterval >= 1 else { return AppConfig.defaultPollInterval }
        return pollInterval
    }

    static func load() -> AppConfig? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    static func save(_ config: AppConfig) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }

    static var template: AppConfig {
        AppConfig(
            baseURL: "http://homeassistant.local:8123",
            token: placeholderToken,
            pollInterval: defaultPollInterval,
            sensors: [
                SensorConfig(
                    name: "Sensör",
                    temperatureEntity: "sensor.sonoff_xxx_temperature",
                    humidityEntity: "sensor.sonoff_xxx_humidity",
                    icon: SensorConfig.defaultIcon
                )
            ]
        )
    }

    @discardableResult
    static func writeTemplateIfMissing() -> Bool {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        try? save(template)
        return true
    }
}

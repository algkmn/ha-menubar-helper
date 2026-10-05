import AppKit

enum SensorIcons {
    private static let catalogPath =
        "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/symbol_order.plist"

    private static let languageSuffixes: Set<String> = [
        "ar", "hi", "ja", "ko", "th", "zh", "he", "my", "km",
        "bn", "ta", "te", "kn", "gu", "ml", "or", "pa", "si", "rtl"
    ]

    static let all: [String] = loadCatalog()

    static func search(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.contains(trimmed) }
    }

    static func image(named name: String, pointSize: CGFloat = 12, weight: NSFont.Weight = .regular) -> NSImage? {
        let resolved = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: SensorConfig.defaultIcon, accessibilityDescription: nil)
        guard let resolved else { return nil }
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let configured = resolved.withSymbolConfiguration(configuration) ?? resolved
        configured.isTemplate = true
        return configured
    }

    private static func loadCatalog() -> [String] {
        guard let names = NSArray(contentsOfFile: catalogPath) as? [String], !names.isEmpty else {
            return fallback
        }
        let filtered = names.filter { name in
            guard let suffix = name.split(separator: ".").last else { return true }
            return !languageSuffixes.contains(String(suffix))
        }
        return filtered.isEmpty ? fallback : filtered
    }

    private static let fallback = [
        "thermometer.medium", "thermometer.sun", "thermometer.snowflake",
        "house", "building.2", "door.left.hand.closed", "stairs",
        "bed.double", "sofa", "fork.knife", "refrigerator",
        "shower", "bathtub", "washer", "lightbulb",
        "desktopcomputer", "laptopcomputer", "tv", "books.vertical",
        "car", "leaf", "sun.max", "moon.stars",
        "snowflake", "flame", "drop", "humidity", "wind", "cloud"
    ]
}

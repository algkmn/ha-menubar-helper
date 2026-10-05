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

    static func image(
        named name: String,
        pointSize: CGFloat = 12,
        weight: NSFont.Weight = .regular,
        hexColor: String? = nil
    ) -> NSImage? {
        let resolved = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: SensorConfig.defaultIcon, accessibilityDescription: nil)
        guard let resolved else { return nil }

        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(.preferringMonochrome())
        let configured = resolved.withSymbolConfiguration(configuration) ?? resolved
        configured.isTemplate = true

        guard let tint = hexColor.flatMap({ NSColor(hexString: $0) }) else { return configured }

        let tinted = NSImage(size: configured.size, flipped: false) { rect in
            configured.draw(in: rect)
            tint.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
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


extension NSColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }
}

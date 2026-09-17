import Foundation

enum Format {
    static let placeholder = "—"

    static func number(_ raw: String, decimals: Int) -> String {
        guard let value = Double(raw) else { return placeholder }
        return String(format: "%.\(decimals)f", value)
    }

    static func temperature(_ reading: SensorReading?, spaced: Bool = false) -> String {
        guard let reading else { return placeholder }
        let value = number(reading.state, decimals: 1)
        guard value != placeholder else { return placeholder }
        return value + (spaced ? " " : "") + (reading.unit ?? "°C")
    }

    static func humidity(_ reading: SensorReading?) -> String {
        guard let reading else { return placeholder }
        let value = number(reading.state, decimals: 0)
        guard value != placeholder else { return placeholder }
        return "%" + value
    }

    static func shortError(_ error: Error) -> String {
        if let error = error as? HAError {
            switch error {
            case .http(let code): return "HTTP \(code)"
            case .badURL: return "geçersiz adres"
            case .decode: return "çözümleme"
            }
        }
        return (error as NSError).localizedDescription
    }

    static func time(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

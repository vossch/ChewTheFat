import Foundation

/// Parses free-text height strings into centimeters. The agent captures height
/// as whatever the user typed ("5'11"", "180 cm", "71 in", "5 ft 10") — this
/// is the single place that normalizes it, so prompt variations don't leak
/// into the tool layer.
///
/// Recognized forms (case-insensitive, tolerant of whitespace):
///   - `5'11"`, `5' 11"`, `5'11`, `5’11”` (smart quotes)
///   - `5-11`, `5/11`
///   - `5 ft 11 in`, `5 feet 11 inches`, `5 ft`, `5ft11in`
///   - `180 cm`, `180cm`, `1.8 m`
///   - `71 in`, `71 inches`, `71"`
///   - bare number -> interpreted as cm if >= 90, else feet
enum HeightParser {
    static let minCm: Double = 60
    static let maxCm: Double = 260

    static func parseCentimeters(_ raw: String) -> Double? {
        let cleaned = normalize(raw)
        guard !cleaned.isEmpty else { return nil }

        if let cm = matchMeters(cleaned) { return validate(cm) }
        if let cm = matchCentimeters(cleaned) { return validate(cm) }
        if let cm = matchInchesOnly(cleaned) { return validate(cm) }
        if let cm = matchFeetInches(cleaned) { return validate(cm) }
        if let cm = matchBareNumber(cleaned) { return validate(cm) }

        return nil
    }

    private static func normalize(_ raw: String) -> String {
        let smartQuoteMap: [Character: Character] = [
            "\u{2018}": "'", "\u{2019}": "'",
            "\u{201C}": "\"", "\u{201D}": "\""
        ]
        let swapped = String(raw.map { smartQuoteMap[$0] ?? $0 })
        return swapped.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func validate(_ cm: Double) -> Double? {
        guard cm.isFinite, cm >= minCm, cm <= maxCm else { return nil }
        return cm
    }

    private static func matchMeters(_ s: String) -> Double? {
        // e.g. "1.8 m", "1.82m"
        guard let range = s.range(of: #"^(\d+(?:\.\d+)?)\s*m(?:eters?)?$"#, options: .regularExpression) else { return nil }
        let digits = s[range].filter { "0123456789.".contains($0) }
        guard let meters = Double(digits) else { return nil }
        return meters * 100
    }

    private static func matchCentimeters(_ s: String) -> Double? {
        guard let range = s.range(of: #"^(\d+(?:\.\d+)?)\s*(cm|centimeters?)$"#, options: .regularExpression) else { return nil }
        let digits = s[range].prefix { $0.isNumber || $0 == "." }
        return Double(digits)
    }

    private static func matchInchesOnly(_ s: String) -> Double? {
        guard let range = s.range(of: #"^(\d+(?:\.\d+)?)\s*(in|inch|inches|")$"#, options: .regularExpression) else { return nil }
        let digits = s[range].prefix { $0.isNumber || $0 == "." }
        guard let inches = Double(digits) else { return nil }
        return inches * 2.54
    }

    private static func matchFeetInches(_ s: String) -> Double? {
        // Handles: 5'11", 5' 11", 5'11, 5-11, 5/11, 5 ft 11 in, 5ft11in, 5 feet 11 inches, 5 ft, 5'
        let patterns: [String] = [
            #"^(\d+(?:\.\d+)?)\s*(?:'|ft|feet)\s*(\d+(?:\.\d+)?)?\s*(?:"|in|inch|inches)?$"#,
            #"^(\d+)\s*[-/]\s*(\d+)$"#
        ]
        for pattern in patterns {
            guard let match = s.range(of: pattern, options: .regularExpression) else { continue }
            let captured = s[match]
            let parts = captured
                .replacingOccurrences(of: #"[^0-9\.\s]"#, with: " ", options: .regularExpression)
                .split(whereSeparator: { $0.isWhitespace })
                .compactMap { Double($0) }
            guard let feet = parts.first, feet > 0 else { continue }
            let inches = parts.count > 1 ? parts[1] : 0
            guard inches < 12 else { return nil }
            return feet * 30.48 + inches * 2.54
        }
        return nil
    }

    private static func matchBareNumber(_ s: String) -> Double? {
        guard let value = Double(s) else { return nil }
        // Heuristic: small values are feet (e.g. "5.8" -> 5'9.6"), large are cm.
        if value >= 90 { return value }
        if value >= 3 && value < 8 { return value * 30.48 }
        return nil
    }
}

import Foundation

enum URLInput {
    static func normalize(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = URL(string: trimmed), existing.scheme != nil, existing.host != nil {
            return existing
        }
        return URL(string: "https://\(trimmed)")
    }
}

import Foundation

public enum FocusDomains {
    /// Accept domains or HTTP(S) URLs, never wildcards or arbitrary rule syntax.
    public static func normalize(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty,
              let url = URLComponents(string: text.contains("://") ? text : "https://" + text),
              ["http", "https"].contains(url.scheme ?? ""),
              url.user == nil, url.password == nil, url.port == nil,
              let host = url.host?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              host.count <= 253 else { return nil }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ label in
            !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-"
                && label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
        }) else { return nil }
        return host
    }
}

public struct BrowserFocusState: Codable, Equatable, Sendable {
    public var active: Bool
    public var domains: [String]
    public var expiresAt: Double
    public var remaining: Double

    public init(enabled: Bool, domains: [String], engine: TimerEngine, timerNow: Double, wallNow: Double) {
        self.domains = domains
        remaining = engine.value(at: timerNow)
        active = enabled && engine.mode == .timer && engine.isRunning && remaining > 0 && !domains.isEmpty
        expiresAt = active ? wallNow + min(4, remaining) : 0
    }

    public func isValid(at now: Double) -> Bool {
        active && expiresAt > now && expiresAt <= now + 5 && remaining > 0
    }

    public static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NotchTimer/browser-focus.json")
    }
}

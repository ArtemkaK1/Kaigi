import Foundation

struct MeetingLinkResolver {
    static func validated(_ url: URL) -> URL? {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased(), host.contains("."),
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              !host.contains("%"), !host.hasSuffix(".local"), host != "localhost",
              !host.split(separator: ".").allSatisfy({ Int($0) != nil }) else { return nil }
        return url
    }
    static func provider(for host: String, path: String) -> String? {
        func domain(_ value: String) -> Bool { host == value || host.hasSuffix("." + value) }
        if host == "meet.google.com", path.count > 1 { return "Google Meet" }
        if (domain("zoom.us") || domain("zoom.com")), path.hasPrefix("/j/") || path.hasPrefix("/my/") { return "Zoom" }
        if (domain("teams.microsoft.com") || domain("teams.live.com")), path.contains("meet") { return "Microsoft Teams" }
        if domain("webex.com"), path.count > 1 { return "Webex" }
        return nil
    }
    func resolve(url: URL?, location: String?, notes: String?) -> [MeetingLink] {
        var candidates = url.map { [$0] } ?? []
        let text = [location, notes].compactMap { $0 }.joined(separator: "\n")
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            candidates += detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url)
        }
        var seen = Set<String>()
        return candidates.compactMap { candidate in
            guard let safe = Self.validated(candidate), seen.insert(safe.absoluteString).inserted else { return nil }
            let provider = Self.provider(for: safe.host!.lowercased(), path: safe.path)
            return MeetingLink(url: safe, provider: provider ?? "Open HTTPS link", recognized: provider != nil)
        }.sorted { $0.recognized && !$1.recognized }
    }
}

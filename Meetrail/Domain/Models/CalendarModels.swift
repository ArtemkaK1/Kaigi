import Foundation

struct CalendarID: RawRepresentable, Codable, Hashable, Sendable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
    init(rawValue: String) { self.rawValue = rawValue }
    init(provider: CalendarProviderKind, account: AccountID, externalID: String) {
        rawValue = provider == .system ? externalID : "provider:" + [provider.rawValue, account.rawValue, externalID].map { "\($0.utf8.count):\($0)" }.joined()
    }
}
struct AccountID: RawRepresentable, Codable, Hashable, Sendable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
}
enum CalendarProviderKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case system, google, microsoft, yandex, zoho, calDAV
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Apple / System Calendars"
        case .google: "Google Calendar"
        case .microsoft: "Microsoft Outlook / Microsoft 365"
        case .yandex: "Yandex Calendar"
        case .zoho: "Zoho Calendar"
        case .calDAV: "Other CalDAV"
        }
    }
}
enum AccountConnectionState: String, Codable, Sendable { case connected, notConnected, permissionDenied, comingSoon }
struct CalendarAccount: Identifiable, Hashable, Sendable {
    let id: AccountID
    let provider: CalendarProviderKind
    let name: String
    let state: AccountConnectionState
}
struct CalendarColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    static let neutral = CalendarColor(red: 0.5, green: 0.5, blue: 0.5)
}
struct CalendarDescriptor: Identifiable, Hashable, Sendable {
    let id: CalendarID
    let accountID: AccountID
    let name: String
    let color: CalendarColor
    let isAvailable: Bool
}
struct CalendarCatalog: Sendable {
    let accounts: [CalendarAccount]
    let calendars: [CalendarDescriptor]
    static let empty = CalendarCatalog(accounts: [], calendars: [])
}
// A calendar occurrence is also the notes-first Meeting domain entity.
typealias CalendarEvent = Meeting

enum OnboardingStage: String, Codable, CaseIterable, Sendable { case welcome, connect, selection, ready }
enum OnboardingDisposition: String, Codable, Sendable { case inProgress, skipped, completed }
struct OnboardingProgress: Codable, Equatable, Sendable {
    var stage: OnboardingStage = .welcome
    var disposition: OnboardingDisposition = .inProgress
}

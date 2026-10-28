import Foundation

@MainActor final class AppPreferencesStore: CalendarPreferences, OnboardingPreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    var selectedCalendarIDs: Set<CalendarID>? {
        get { defaults.stringArray(forKey: "selectedCalendars").map { Set($0.map { CalendarID(rawValue: $0) }) } }
        set {
            if let newValue { defaults.set(newValue.map(\.rawValue).sorted(), forKey: "selectedCalendars") }
            else { defaults.removeObject(forKey: "selectedCalendars") }
        }
    }
    var onboardingProgress: OnboardingProgress? {
        get { defaults.data(forKey: "calendarOnboarding.v1").flatMap { try? JSONDecoder().decode(OnboardingProgress.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "calendarOnboarding.v1") }
    }
}

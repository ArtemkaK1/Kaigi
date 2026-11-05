import Foundation

/// Closed payload vocabulary: no user content or identifiers can enter an event.
enum AnalyticsEvent: Equatable, Sendable {
    enum PermissionResult: String, CaseIterable, Sendable { case granted, denied, error }
    enum ConnectionResult: String, CaseIterable, Sendable { case success, denied, error }
    enum ExportResult: String, CaseIterable, Sendable { case success, cancelled, error }
    enum Direction: String, CaseIterable, Sendable { case previous, next, today }
    enum SelectionState: String, CaseIterable, Sendable { case all, none }
    enum Value: Equatable, Sendable { case string(String), integer(Int) }

    case onboardingStarted, onboardingConnectTapped, onboardingPermissionResult(PermissionResult)
    case onboardingCompleted, onboardingSkipped
    case menubarAgendaOpened, agendaDayChanged(Direction), agendaMeetingOpened, agendaJoinTapped, agendaRecoveredNoteOpened
    case notesOpened, notesEditStarted, notesJoinTapped, notesExportTapped, notesExportResult(ExportResult)
    case accountsOpened, accountsConnectTapped, accountsConnectResult(ConnectionResult)
    case calendarsOpened, calendarsSearchUsed, calendarsVisibilityChanged(Bool), calendarsAllChanged(SelectionState)
    case settingsOpened, settingsRemindersChanged(Bool), settingsLaunchAtLoginChanged(Bool)

    var name: String {
        switch self {
        case .onboardingStarted: "onboarding_started"
        case .onboardingConnectTapped: "onboarding_connect_tapped"
        case .onboardingPermissionResult: "onboarding_permission_result"
        case .onboardingCompleted: "onboarding_completed"
        case .onboardingSkipped: "onboarding_skipped"
        case .menubarAgendaOpened: "menubar_agenda_opened"
        case .agendaDayChanged: "agenda_day_changed"
        case .agendaMeetingOpened: "agenda_meeting_opened"
        case .agendaJoinTapped: "agenda_join_tapped"
        case .agendaRecoveredNoteOpened: "agenda_recovered_note_opened"
        case .notesOpened: "notes_opened"
        case .notesEditStarted: "notes_edit_started"
        case .notesJoinTapped: "notes_join_tapped"
        case .notesExportTapped: "notes_export_tapped"
        case .notesExportResult: "notes_export_result"
        case .accountsOpened: "accounts_opened"
        case .accountsConnectTapped: "accounts_connect_tapped"
        case .accountsConnectResult: "accounts_connect_result"
        case .calendarsOpened: "calendars_opened"
        case .calendarsSearchUsed: "calendars_search_used"
        case .calendarsVisibilityChanged: "calendars_visibility_changed"
        case .calendarsAllChanged: "calendars_all_changed"
        case .settingsOpened: "settings_opened"
        case .settingsRemindersChanged: "settings_reminders_changed"
        case .settingsLaunchAtLoginChanged: "settings_launch_at_login_changed"
        }
    }

    var parameters: [String: Value] {
        switch self {
        case .onboardingPermissionResult(let result): ["result": .string(result.rawValue)]
        case .accountsConnectResult(let result): ["result": .string(result.rawValue)]
        case .notesExportResult(let result): ["result": .string(result.rawValue)]
        case .agendaDayChanged(let direction): ["direction": .string(direction.rawValue)]
        case .calendarsAllChanged(let state): ["selection_state": .string(state.rawValue)]
        case .calendarsVisibilityChanged(let enabled), .settingsRemindersChanged(let enabled), .settingsLaunchAtLoginChanged(let enabled):
            ["enabled": .integer(enabled ? 1 : 0)]
        default: [:]
        }
    }
}

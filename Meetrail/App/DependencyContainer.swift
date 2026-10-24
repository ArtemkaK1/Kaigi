import Foundation

@MainActor final class DependencyContainer {
    let coordinator: CalendarAccountCoordinator
    let visibility: CalendarVisibilityUseCase
    let noteUseCases: NoteUseCases
    let contextUseCase: MeetingContextUseCase
    let accounts: CalendarAccountsViewModel
    let onboarding: OnboardingViewModel
    let settings: SettingsViewModel
    private let systemPreferences: any PreferencesService
    private let ai: any AIRefinementService
    private let joinUseCase: ConferenceJoinUseCase
    private let actions: any ApplicationActions
    private var detailModels: [NoteID: MeetingDetailViewModel] = [:]
    private(set) var agenda: AgendaViewModel!
    init(providers: [any CalendarProvider], store: any NotesStore, preferences: AppPreferencesStore, systemPreferences: any PreferencesService, ai: any AIRefinementService, opener: any LinkOpening, permissionSettings: any PermissionSettingsOpening, actions: any ApplicationActions, sample: Bool, suppressOnboarding: Bool, closeOnboarding: @escaping () -> Void) throws {
        self.actions = actions; self.ai = ai; self.systemPreferences = systemPreferences
        coordinator = CalendarAccountCoordinator(providers: providers)
        visibility = CalendarVisibilityUseCase(preferences: preferences, coordinator: coordinator)
        noteUseCases = NoteUseCases(store: store); contextUseCase = MeetingContextUseCase(store: store)
        joinUseCase = ConferenceJoinUseCase(opener: opener)
        // Add only a new preferences key; preserve legacy calendar IDs and all note data.
        if preferences.onboardingProgress == nil {
            let hasNotes = !(try store.fetchNotes()).isEmpty
            let returningUser = preferences.selectedCalendarIDs != nil || hasNotes
            preferences.onboardingProgress = OnboardingProgress(stage: .welcome, disposition: returningUser || suppressOnboarding ? .completed : .inProgress)
        }
        accounts = CalendarAccountsViewModel(coordinator: coordinator, visibility: visibility, permissionSettings: permissionSettings)
        onboarding = OnboardingViewModel(preferences: preferences, accounts: accounts, closeWindow: closeOnboarding)
        var refreshAgenda: (() -> Void)?
        settings = SettingsViewModel(service: systemPreferences, actions: actions, onChanged: { refreshAgenda?() })
        let agendaUseCase = AgendaUseCase(coordinator: coordinator, visibility: visibility, notes: noteUseCases, preferences: systemPreferences, sample: sample)
        agenda = AgendaViewModel(useCase: agendaUseCase, selection: MeetingSelectionUseCase(store: store), join: joinUseCase, actions: actions, detailFactory: { [unowned self] note, meeting in self.detail(note: note, meeting: meeting) })
        refreshAgenda = { [weak self] in
            self?.agenda.refresh()
            self?.detailModels.values.forEach { $0.refreshPreferences() }
        }
        agenda.refresh()
    }
    func detail(note: NoteRecord, meeting: Meeting?) -> MeetingDetailViewModel {
        if let existing = detailModels[note.id] { if let meeting { existing.updateMeeting(meeting) }; existing.reloadContext(); return existing }
        let model = MeetingDetailViewModel(note: note, meeting: meeting, notes: noteUseCases, context: contextUseCase, ai: ai, preferences: systemPreferences, join: joinUseCase, actions: actions, onSaved: { [weak self] in self?.agenda.notesChanged() })
        detailModels[note.id] = model; return model
    }
    func detail(id: NoteID) throws -> MeetingDetailViewModel { detail(note: try noteUseCases.note(id), meeting: nil) }
    func flushDrafts() throws {
        for detail in detailModels.values { try detail.flushDraft() }
        try noteUseCases.flush()
    }
}

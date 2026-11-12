import Foundation

@MainActor final class DependencyContainer {
    let analytics: any AnalyticsTracking
    let access: FeatureAccess
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
    var hasUnconfirmedContextDrafts: Bool { detailModels.values.contains(where: \.hasUnconfirmedContextDraft) }

    init(providers: [any CalendarProvider], store: any NotesStore, preferences: AppPreferencesStore, systemPreferences: any PreferencesService, ai: any AIRefinementService, opener: any LinkOpening, permissionSettings: any PermissionSettingsOpening, actions: any ApplicationActions, sample: Bool, suppressOnboarding: Bool, access: FeatureAccess, analytics: any AnalyticsTracking = NoOpAnalyticsTracker(), closeOnboarding: @escaping () -> Void) throws {
        self.analytics = analytics
        self.access = access
        self.actions = actions; self.ai = ai; self.systemPreferences = systemPreferences
        coordinator = CalendarAccountCoordinator(providers: providers)
        visibility = CalendarVisibilityUseCase(preferences: preferences, coordinator: coordinator)
        noteUseCases = NoteUseCases(store: store, access: access); contextUseCase = MeetingContextUseCase(store: store, access: access)
        joinUseCase = ConferenceJoinUseCase(opener: opener)
        // Add only a new preferences key; preserve legacy calendar IDs and all note data.
        if preferences.onboardingProgress == nil {
            let hasNotes = !(try store.fetchNotes()).isEmpty
            let returningUser = preferences.selectedCalendarIDs != nil || hasNotes
            preferences.onboardingProgress = OnboardingProgress(stage: .welcome, disposition: returningUser || suppressOnboarding ? .completed : .inProgress)
        }
        accounts = CalendarAccountsViewModel(coordinator: coordinator, visibility: visibility, permissionSettings: permissionSettings, access: access, analytics: analytics)
        onboarding = OnboardingViewModel(preferences: preferences, accounts: accounts, analytics: analytics, closeWindow: closeOnboarding)
        var refreshAgenda: (() -> Void)?
        settings = SettingsViewModel(service: systemPreferences, actions: actions, access: access, analytics: analytics, onChanged: { refreshAgenda?() })
        let agendaUseCase = AgendaUseCase(coordinator: coordinator, visibility: visibility, notes: noteUseCases, preferences: systemPreferences, sample: sample, access: access)
        agenda = AgendaViewModel(useCase: agendaUseCase, selection: MeetingSelectionUseCase(store: store), join: joinUseCase, actions: actions, analytics: analytics, detailFactory: { [unowned self] note, meeting in self.detail(note: note, meeting: meeting) })
        refreshAgenda = { [weak self] in
            self?.agenda.refresh()
            self?.detailModels.values.forEach { $0.refreshPreferences() }
        }
        access.observeChanges { [weak self] in
            self?.detailModels.values.forEach { $0.accessChanged() }
        }
        agenda.refresh()
    }

    func detail(note: NoteRecord, meeting: Meeting?) -> MeetingDetailViewModel {
        if let existing = detailModels[note.id] {
            existing.updateOccurrence(note, meeting: meeting)
            return existing
        }
        let model = MeetingDetailViewModel(note: note, meeting: meeting, notes: noteUseCases, context: contextUseCase, ai: ai, preferences: systemPreferences, join: joinUseCase, actions: actions, access: access, analytics: analytics, onSaved: { [weak self, seriesID = note.seriesID] in
            self?.agenda.notesChanged()
            self?.detailModels.values.filter { $0.note.seriesID == seriesID }.forEach { $0.reloadContext() }
        })
        detailModels[note.id] = model; return model
    }

    func detail(id: NoteID) throws -> MeetingDetailViewModel { detail(note: try noteUseCases.note(id), meeting: nil) }

    func flushDrafts() throws {
        for detail in detailModels.values { try detail.flushDraft() }
        try noteUseCases.flush()
    }
}

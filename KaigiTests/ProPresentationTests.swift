import Testing
@testable import Meetrail

@MainActor struct ProPresentationTests {
    @Test func settingsAndPaywallReadTheSameEntitlementAcrossTransitions() throws {
        let fixture = try TestComposition(entitlement: .init(.loading))
        defer { fixture.clearPreferences() }
        let settings = fixture.container.settings
        let pro = fixture.container.pro
        for state in [EntitlementState.loading, .free, .pro, .free] {
            fixture.entitlement.send(state)
            #expect(settings.proState == state && pro.state == state)
            #expect(pro.capabilities == ProCapability.allCases)
            settings.showPro()
        }
        #expect(fixture.actions.proEntries == Array(repeating: .settings, count: 4))
    }

    @Test func contextualRoutesRequireReleasedFeaturesAndResolvedFreeAccess() throws {
        let fixture = try TestComposition(
            features: FeatureToggles(enabled: [.recurringContext, .floatingNotes, .aiCleanUp]),
            entitlement: .init(.loading), proPresentation: .init(contextualEntryPointsEnabled: true)
        )
        defer { fixture.clearPreferences() }
        let note = try fixture.store.openNote(for: KaigiTests().meeting())
        let detail = fixture.container.detail(note: note, meeting: nil)
        let entries: [ProEntryPoint] = [.meetingContext, .floatingNotes, .ai(.cleanUp), .ai(.structure)]

        for state in [EntitlementState.loading, .free, .pro, .free] {
            fixture.entitlement.send(state)
            let expected = state == .free ? Array(entries.dropLast()) : []
            #expect(entries.filter(detail.showsProEntry) == expected)
            fixture.actions.proEntries.removeAll()
            for entry in entries { detail.showPro(from: entry) }
            #expect(fixture.actions.proEntries == expected)
        }
        #expect(fixture.actions.floating.isEmpty && fixture.actions.contextWindows.isEmpty)
        #expect(fixture.container.pro.capabilities == [.context, .floatingNotes, .ai])
        #expect(fixture.container.pro.offersCleanUp && !fixture.container.pro.offersStructure)
        detail.float()
        detail.showHistoryAndContext()
        detail.refine(.cleanUp)
        #expect(fixture.actions.floating.isEmpty && fixture.actions.contextWindows.isEmpty && !detail.refining)
    }

    @Test func launchLimitsContextualEntryPointsToSyntheticEntitlementQA() {
        for arguments in [[], ["--sample"], ["--simulate-entitlement"], ["--sample", "--all-features"],
                          ["--sample", "--marketing-fixtures", "--simulate-entitlement"]] {
            #expect(!ProPresentationPolicy.forLaunch(arguments: arguments).contextualEntryPointsEnabled)
        }
        let qa = ProPresentationPolicy.forLaunch(arguments: ["--sample", "--simulate-entitlement"])
        #if DEBUG
        #expect(qa.contextualEntryPointsEnabled)
        #else
        #expect(!qa.contextualEntryPointsEnabled)
        #endif
    }
}

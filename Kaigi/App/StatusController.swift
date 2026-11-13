import AppKit
import FirebaseCore
import SwiftUI

@MainActor final class AgendaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) { orderOut(nil) }

    func setFloating(_ enabled: Bool) {
        if enabled { styleMask.insert(.utilityWindow) } else { styleMask.remove(.utilityWindow) }
        isFloatingPanel = enabled
        level = enabled ? .floating : .normal
        hidesOnDeactivate = false
    }
}
@MainActor final class AppRouter: ApplicationActions {
    weak var windows: AppWindowCoordinator?
    private let exporter: MarkdownExporter
    private let access: FeatureAccess
    private let proPresentation: ProPresentationPolicy

    init(exporter: MarkdownExporter, access: FeatureAccess, proPresentation: ProPresentationPolicy = .init()) {
        self.exporter = exporter
        self.access = access
        self.proPresentation = proPresentation
    }

    func showAccounts() { guard access.allows(.calendarManagement) else { return }; windows?.showAccounts() }

    func showFloatingNote(_ id: NoteID) { guard access.allows(.floatingNotes) else { return }; windows?.showFloatingNote(id) }

    func showPro(from entry: ProEntryPoint) {
        guard proPresentation.canPresent(from: entry, access: access) else { return }
        windows?.showPro()
    }

    func showMeetingContext(_ id: NoteID) { guard access.allowsMeetingContextWindow else { return }; windows?.showMeetingContext(id) }

    @discardableResult func export(_ document: MarkdownDocument) async throws -> ExportOutcome { guard access.allows(.markdownExport) else { return .cancelled }; return try await exporter.export(document) }

    func dismissOnboarding() { windows?.closeOnboarding() }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: AppWindowCoordinator?
    private(set) var container: DependencyContainer?
    private var router: AppRouter?
    private var startupFailure: Error?
    private var firebaseAnalytics: FirebaseAnalyticsAdapter?
    #if DEBUG
    private var entitlementSimulator: SimulatedEntitlementProvider?
    var canSimulateEntitlement: Bool { entitlementSimulator != nil }

    func simulateEntitlement(_ state: EntitlementState) { entitlementSimulator?.simulate(state) }
    #endif

    override init() {
        super.init()
        StartupTrace.mark("delegate.begin")
        // Settings scene content is constructed before didFinishLaunching. Resolve
        // its injected ViewModel first, without creating windows or requesting access.
        do {
            let arguments = ProcessInfo.processInfo.arguments
            let provider = EntitlementLaunchPolicy.makeProvider(arguments: arguments)
            let access = FeatureAccess(toggles: .forLaunch(arguments: arguments), entitlement: EntitlementStore(provider: provider))
            #if DEBUG
            if arguments.contains("--simulate-entitlement") {
                entitlementSimulator = provider as? SimulatedEntitlementProvider
            }
            #endif
            let proPresentation = ProPresentationPolicy.forLaunch(arguments: arguments)
            let router = AppRouter(exporter: MarkdownExporter(), access: access, proPresentation: proPresentation)
            self.router = router
            let environment = ProcessInfo.processInfo.environment
            let isTesting = environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil || NSClassFromString("XCTestCase") != nil
            let analytics: any AnalyticsTracking
            if AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: ProcessInfo.processInfo.arguments, isTesting: isTesting) {
                let adapter = FirebaseAnalyticsAdapter()
                firebaseAnalytics = adapter
                analytics = adapter
            } else {
                analytics = NoOpAnalyticsTracker()
            }
            container = try DependencyContainer.makeLive(actions: router, access: access, proPresentation: proPresentation, analytics: analytics, isTesting: isTesting, closeOnboarding: { [weak router] in router?.dismissOnboarding() })
        } catch { startupFailure = error }
        StartupTrace.mark("delegate.end")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupTrace.mark("didFinishLaunching")
        if let firebaseAnalytics {
            FirebaseApp.configure()
            firebaseAnalytics.configurationDidComplete()
            self.firebaseAnalytics = nil
        }
        NSApp.setActivationPolicy(.accessory)
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--sample"), let index = arguments.firstIndex(of: "-NSAppearance"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "Aqua": NSApp.appearance = NSAppearance(named: .aqua)
            case "DarkAqua": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: break
            }
        }
        #endif
        guard let container, let router else {
            let alert = NSAlert(); alert.messageText = "Kaigi could not open its note store"
            alert.informativeText = "Existing data has not been replaced. \(startupFailure?.localizedDescription ?? "Initialization failed")"
            alert.runModal(); NSApp.terminate(nil); return
        }
        let windows = AppWindowCoordinator(container: container); self.windows = windows; router.windows = windows
        #if DEBUG
        windows.entitlementSimulator = entitlementSimulator
        #endif
        windows.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { windows?.showAgenda() }; return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if container?.hasUnconfirmedContextDrafts == true {
            let alert = NSAlert()
            alert.messageText = "You have unconfirmed context drafts"
            alert.informativeText = "Keep Kaigi open to copy your drafts or return to them later in this session."
            alert.addButton(withTitle: "Keep Kaigi Open")
            alert.addButton(withTitle: "Quit and Discard Context Drafts")
            guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        }
        do { try container?.flushDrafts(); return .terminateNow }
        catch {
            let alert = NSAlert(); alert.messageText = "Your notes could not be saved"
            alert.informativeText = "Keep Kaigi open and retry saving. \(error.localizedDescription)"
            alert.addButton(withTitle: "Keep Kaigi Open"); alert.addButton(withTitle: "Quit Without Saving")
            return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
        }
    }
}
@MainActor final class AppWindowCoordinator: NSObject, NSWindowDelegate, NSPopoverDelegate {
    private let container: DependencyContainer
    private var statusItem: NSStatusItem?
    private let agendaPopover = NSPopover()
    private var agendaIsPresented = false
    private var onboardingWindow: NSWindow?
    private var accountsWindow: NSWindow?
    private var proWindow: NSWindow?
    private weak var proSourceWindow: NSWindow?
    private var returnToAgendaAfterPro = false
    private var hasSizedProWindow = false
    private var floatingPanels: [NoteID: AgendaPanel] = [:]
    private var contextWindows: [NoteID: NSWindow] = [:]
    private var notificationTokens: [NSObjectProtocol] = []
    #if DEBUG
    var entitlementSimulator: SimulatedEntitlementProvider?
    #endif

    init(container: DependencyContainer) {
        self.container = container
        super.init()
        container.access.observeChanges { [weak self] in self?.updateWindowAccess() }
    }

    func start() {
        StartupTrace.mark("status.begin")
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength); statusItem = item
        if let symbol = NSImage(named: "KaigiStatus") {
            symbol.isTemplate = true
            symbol.size = NSSize(width: AppLayout.menuBarSymbolSize, height: AppLayout.menuBarSymbolSize)
            symbol.accessibilityDescription = "Kaigi"
            item.button?.image = symbol
        }
        item.button?.setAccessibilityLabel("Kaigi"); item.button?.toolTip = "Kaigi — Your meetings. Your notes. All connected."
        item.button?.target = self; item.button?.action = #selector(toggle)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        StartupTrace.mark("status.visible")
        agendaPopover.delegate = self
        agendaPopover.behavior = .transient
        agendaPopover.animates = false
        agendaPopover.appearance = NSApp.appearance
        let visibleHeight = statusItem?.button?.window?.screen?.visibleFrame.height ?? 800
        var maximumHeight = visibleHeight - AppSpacing.sm
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--constrained-height") { maximumHeight = min(maximumHeight, AppLayout.reviewHeight) }
        #endif
        let host = NSHostingController(
            rootView: AgendaView(model: container.agenda!, maximumHeight: maximumHeight, onHeightChange: { [weak self] height in
                self?.resizeAgenda(height: height)
            })
                .tint(AppColors.accent)
                .modifier(ReviewLayoutModifier())
        ); host.sizingOptions = []
        agendaPopover.contentViewController = host
        agendaPopover.contentSize = NSSize(width: AppLayout.panelWidth, height: AppLayout.emptyHeight)
        for name in [NSNotification.Name.NSCalendarDayChanged, NSNotification.Name.NSSystemTimeZoneDidChange] {
            notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.container.coordinator.notifyChange() }
            })
        }
        DispatchQueue.main.async { [weak self] in
            StartupTrace.mark("status.nextRunLoop")
            guard let self else { return }
            if self.container.onboarding.shouldAutomaticallyPresent { self.showOnboarding(); return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--show-agenda") { self.showAgenda() }
            #endif
        }
    }

    @objc private func toggle() {
        StartupTrace.mark("status.click")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--startup-timing"), let event = NSApp.currentEvent {
            NSLog("KAIGI_STARTUP inputQueueMs=%.3f", (ProcessInfo.processInfo.systemUptime - event.timestamp) * 1000)
        }
        #endif
        if let event = NSApp.currentEvent, event.type == .rightMouseUp, let button = statusItem?.button {
            closeAgenda()
            let menu = NSMenu()
            let settings = menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ","); settings.target = self
            menu.addItem(.separator())
            #if DEBUG
            if entitlementSimulator != nil {
                for (title, state) in [("Simulate Loading", EntitlementState.loading), ("Simulate Free", .free), ("Simulate Pro", .pro)] {
                    let item = menu.addItem(withTitle: title, action: #selector(simulateEntitlement(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = state
                }
                menu.addItem(.separator())
            }
            #endif
            let quit = menu.addItem(withTitle: "Quit Kaigi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); quit.target = NSApp
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        } else if agendaPopover.isShown { closeAgenda() } else { showAgenda() }
    }

    #if DEBUG
    @objc private func simulateEntitlement(_ sender: NSMenuItem) {
        guard let state = sender.representedObject as? EntitlementState else { return }
        entitlementSimulator?.simulate(state)
    }
    #endif

    @objc private func showSettings() {
        closeAgenda(); NSApp.activate(ignoringOtherApps: true)
        // Invoke SwiftUI's existing native Settings command; keep a single scene.
        for item in NSApp.mainMenu?.items ?? [] {
            guard let submenu = item.submenu else { continue }
            if let index = submenu.items.firstIndex(where: { $0.keyEquivalent == "," && $0.keyEquivalentModifierMask.contains(.command) }) {
                submenu.performActionForItem(at: index); return
            }
        }
    }

    func closeAgenda() { agendaPopover.performClose(nil) }

    func showAgenda(keepDay: Bool = false) {
        StartupTrace.mark("panel.begin")
        guard let button = statusItem?.button else { return }
        if !keepDay { container.agenda.showToday() }
        NSApp.activate(ignoringOtherApps: true)
        agendaPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = agendaPopover.contentViewController?.view.window {
            window.title = "Kaigi agenda"
            window.makeKey()
        }
        StartupTrace.mark("panel.ordered")
        DispatchQueue.main.async { StartupTrace.mark("panel.nextRunLoop") }
    }

    func popoverDidShow(_ notification: Notification) {
        guard !agendaIsPresented else { return }
        agendaIsPresented = true
        container.analytics.track(.menubarAgendaOpened)
    }

    func popoverDidClose(_ notification: Notification) { agendaIsPresented = false }

    private func resizeAgenda(height requestedHeight: CGFloat) {
        let visible = statusItem?.button?.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let height = min(max(1, requestedHeight), visible.height - AppSpacing.sm)
        agendaPopover.contentSize = NSSize(width: AppLayout.panelWidth, height: height)
    }

    func showPro() {
        let source = NSApp.keyWindow
        let fromAgenda = agendaPopover.isShown
        if source !== proWindow || fromAgenda {
            returnToAgendaAfterPro = fromAgenda
            proSourceWindow = fromAgenda ? nil : source
        }

        if proWindow == nil {
            let display = source?.screen ?? statusItem?.button?.window?.screen ?? NSScreen.main
            let visibleFrame = display?.visibleFrame
            let width = min(AppLayout.proWindowWidth, visibleFrame.map { $0.width - AppSpacing.lg } ?? AppLayout.proWindowWidth)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: AppSpacing.none),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.title = "Kaigi Pro"
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.delegate = self
            let chrome = window.frameRect(forContentRect: .zero).height
            let maximumHeight = (visibleFrame?.height ?? AppLayout.contextHeight) - chrome - AppSpacing.lg
            let host = NSHostingController(
                rootView: ProView(model: container.pro, maximumHeight: maximumHeight, onHeightChange: { [weak self] height in
                    self?.resizePro(height: height)
                }, close: { [weak window] in window?.performClose(nil) })
                    .frame(width: width)
                    .tint(AppColors.accent)
                    .modifier(ReviewLayoutModifier())
            )
            host.sizingOptions = []
            proWindow = window
            window.contentViewController = host
            if let visibleFrame {
                window.setFrameOrigin(NSPoint(x: visibleFrame.midX - width / 2, y: visibleFrame.midY - window.frame.height / 2))
            } else {
                window.center()
            }
        }

        guard let window = proWindow else { return }
        if source !== window || fromAgenda {
            window.parent?.removeChildWindow(window)
            if !fromAgenda, let source, source.level == .floating {
                source.addChildWindow(window, ordered: .above)
            }
        }
        closeAgenda()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func resizePro(height: CGFloat) {
        guard let window = proWindow, let content = window.contentView, height > 1, abs(content.bounds.height - height) > 0.5 else { return }
        let previousFrame = window.frame
        let nextFrame = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: content.bounds.width, height: height))
        let top = hasSizedProWindow ? previousFrame.maxY : previousFrame.midY + nextFrame.height / 2
        hasSizedProWindow = true
        let frame = NSRect(
            x: previousFrame.minX, y: top - nextFrame.height,
            width: nextFrame.width, height: nextFrame.height
        )
        if let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame {
            let minimumY = visibleFrame.minY + AppSpacing.sm
            let maximumY = visibleFrame.maxY - AppSpacing.sm - frame.height
            var fittedFrame = frame
            fittedFrame.origin.y = max(minimumY, min(maximumY, frame.minY))
            window.setFrame(fittedFrame, display: true)
        } else {
            window.setFrame(frame, display: true)
        }
    }

    func showAccounts() {
        guard container.access.allows(.calendarManagement) else { return }
        closeAgenda(); container.accounts.refresh()
        if accountsWindow == nil {
            accountsWindow = makeWindow(title: "Accounts & Calendars", root: CalendarAccountsView(model: container.accounts))
        }
        let wasVisible = accountsWindow?.isVisible == true
        NSApp.activate(ignoringOtherApps: true); accountsWindow?.makeKeyAndOrderFront(nil)
        if !wasVisible, accountsWindow?.isVisible == true { container.accounts.pagePresented() }
    }

    func showOnboarding() {
        closeAgenda()
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(title: "Welcome to Kaigi", root: OnboardingView(model: container.onboarding, onStageChange: { [weak self] stage in self?.resizeOnboarding(stage) }))
            onboardingWindow?.minSize = NSSize(width: 480, height: 240)
        }
        resizeOnboarding(container.onboarding.stage)
        NSApp.activate(ignoringOtherApps: true); onboardingWindow?.makeKeyAndOrderFront(nil)
        if onboardingWindow?.isVisible == true { container.onboarding.presented() }
    }

    private func resizeOnboarding(_ stage: OnboardingStage) {
        guard let window = onboardingWindow else { return }
        let height: CGFloat = switch stage {
        case .welcome: AppLayout.onboardingWelcomeHeight
        case .ready: AppLayout.onboardingReadyHeight
        case .connect, .selection: AppLayout.onboardingHeight
        }
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        window.setContentSize(NSSize(width: window.contentView?.bounds.width ?? AppLayout.onboardingWidth, height: height))
        window.setFrameOrigin(NSPoint(x: center.x - window.frame.width / 2, y: center.y - window.frame.height / 2))
    }

    func closeOnboarding() { onboardingWindow?.close(); showAgenda() }

    private func makeWindow<V: View>(title: String, root: V) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: AppLayout.onboardingWidth, height: AppLayout.onboardingHeight), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = title; window.isReleasedWhenClosed = false; window.minSize = NSSize(width: 480, height: 360); window.delegate = self
        let calendarArtwork = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal").map { Image(nsImage: NSWorkspace.shared.icon(forFile: $0.path)) }
        let host = NSHostingController(
            rootView: root
                .environment(\.systemCalendarArtwork, calendarArtwork)
                .tint(AppColors.accent)
                .modifier(ReviewLayoutModifier())
        ); host.sizingOptions = []; window.contentViewController = host
        window.setContentSize(NSSize(width: AppLayout.onboardingWidth, height: AppLayout.onboardingHeight)); window.center(); return window
    }

    func showMeetingContext(_ id: NoteID) {
        guard container.access.allowsMeetingContextWindow else { return }
        do {
            let detail = try container.detail(id: id)
            detail.reloadContext()
            if contextWindows[id] == nil {
                let window = makeWindow(title: "History & Context — \(detail.note.title)", root: MeetingContextView(model: detail))
                window.setContentSize(NSSize(width: AppLayout.contextWidth, height: AppLayout.contextHeight))
                window.minSize = NSSize(width: AppLayout.contextMinimumWidth, height: AppLayout.contextMinimumHeight)
                window.center()
                contextWindows[id] = window
            }
            closeAgenda()
            NSApp.activate(ignoringOtherApps: true)
            contextWindows[id]?.makeKeyAndOrderFront(nil)
        } catch { let alert = NSAlert(); alert.messageText = error.localizedDescription; alert.runModal() }
    }

    func showFloatingNote(_ id: NoteID) {
        guard container.access.allows(.floatingNotes) else { return }
        do {
            if let panel = floatingPanels[id] {
                panel.setFloating(true)
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
                return
            }
            let detail = try container.detail(id: id)
            let panel = AgendaPanel(contentRect: NSRect(x: 160, y: 180, width: AppLayout.notesWidth, height: AppLayout.detailHeight), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "Kaigi — \(detail.note.title)"
            panel.setFloating(true)
            panel.isReleasedWhenClosed = false; panel.minSize = NSSize(width: 320, height: 400); panel.delegate = self
            let host = NSHostingController(
                rootView: ScrollView {
                    NoteEditorView(model: detail)
                }
                .tint(AppColors.accent)
            ); host.sizingOptions = []
            panel.contentViewController = host; floatingPanels[id] = panel; NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
        } catch { let alert = NSAlert(); alert.messageText = error.localizedDescription; alert.runModal() }
    }

    private func updateWindowAccess() {
        if !container.access.allows(.floatingNotes) {
            // Keep the existing editor and any draft that failed to save.
            for panel in floatingPanels.values where panel.isFloatingPanel { panel.setFloating(false) }
        }
        if !container.access.allowsMeetingContextWindow {
            for window in Array(contextWindows.values) { window.close() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === proWindow {
            window.parent?.removeChildWindow(window)
            proWindow = nil
            hasSizedProWindow = false
            let source = proSourceWindow
            let restoreAgenda = returnToAgendaAfterPro
            proSourceWindow = nil
            returnToAgendaAfterPro = false
            DispatchQueue.main.async { [weak self, weak source] in
                guard let self, self.proWindow == nil, NSApp.isActive else { return }
                if restoreAgenda { self.showAgenda(keepDay: true) }
                else if source?.isVisible == true { source?.makeKey() }
            }
        }
        if window === accountsWindow { container.accounts.pageDismissed() }
        if window === onboardingWindow { container.onboarding.windowClosed() }
        if let id = floatingPanels.first(where: { $0.value === window })?.key { floatingPanels.removeValue(forKey: id) }
        if let id = contextWindows.first(where: { $0.value === window })?.key { contextWindows.removeValue(forKey: id) }
    }
}

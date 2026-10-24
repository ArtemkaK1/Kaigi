import AppKit
import SwiftUI

@MainActor final class AgendaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}
@MainActor final class AppRouter: ApplicationActions {
    weak var windows: AppWindowCoordinator?
    private let exporter: MarkdownExporter
    init(exporter: MarkdownExporter) { self.exporter = exporter }
    func showAccounts() { windows?.showAccounts() }
    func showFloatingNote(_ id: NoteID) { windows?.showFloatingNote(id) }
    func export(_ document: MarkdownDocument) async throws { try await exporter.export(document) }
    func dismissOnboarding() { windows?.closeOnboarding() }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: AppWindowCoordinator?
    private(set) var container: DependencyContainer?
    private var router: AppRouter?
    private var startupFailure: Error?
    override init() {
        super.init()
        // Settings scene content is constructed before didFinishLaunching. Resolve
        // its injected ViewModel first, without creating windows or requesting access.
        do {
            let router = AppRouter(exporter: MarkdownExporter()); self.router = router
            container = try DependencyContainer.makeLive(actions: router, closeOnboarding: { [weak router] in router?.dismissOnboarding() })
        } catch { startupFailure = error }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
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
            let alert = NSAlert(); alert.messageText = "Meetrail could not open its note store"
            alert.informativeText = "Existing data has not been replaced. \(startupFailure?.localizedDescription ?? "Initialization failed")"
            alert.runModal(); NSApp.terminate(nil); return
        }
        let windows = AppWindowCoordinator(container: container); self.windows = windows; router.windows = windows
        windows.start()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { windows?.showAgenda() }; return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        do { try container?.flushDrafts(); return .terminateNow }
        catch {
            let alert = NSAlert(); alert.messageText = "Your notes could not be saved"
            alert.informativeText = "Keep Meetrail open and retry saving. \(error.localizedDescription)"
            alert.addButton(withTitle: "Keep Meetrail Open"); alert.addButton(withTitle: "Quit Without Saving")
            return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
        }
    }
}
@MainActor final class AppWindowCoordinator: NSObject, NSWindowDelegate {
    private let container: DependencyContainer
    private var statusItem: NSStatusItem?
    private let agendaPanel = AgendaPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    private var onboardingWindow: NSWindow?
    private var accountsWindow: NSWindow?
    private var floatingPanels: [NoteID: AgendaPanel] = [:]
    private var outsideMonitor: Any?
    private var notificationTokens: [NSObjectProtocol] = []
    init(container: DependencyContainer) { self.container = container }
    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength); statusItem = item
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Meetrail")
        item.button?.setAccessibilityLabel("Meetrail"); item.button?.toolTip = "Meetrail — Your meetings. Your notes. All connected."
        item.button?.target = self; item.button?.action = #selector(toggle)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        agendaPanel.title = "Meetrail agenda"; agendaPanel.titleVisibility = .hidden; agendaPanel.titlebarAppearsTransparent = true
        agendaPanel.standardWindowButton(.closeButton)?.isHidden = true
        agendaPanel.isFloatingPanel = true; agendaPanel.becomesKeyOnlyIfNeeded = false
        agendaPanel.level = .floating; agendaPanel.hidesOnDeactivate = true; agendaPanel.isReleasedWhenClosed = false
        agendaPanel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]; agendaPanel.delegate = self
        let visibleHeight = statusItem?.button?.window?.screen?.visibleFrame.height ?? 800
        var maximumHeight = visibleHeight - AppSpacing.sm
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--constrained-height") { maximumHeight = min(maximumHeight, AppLayout.reviewHeight) }
        #endif
        let host = NSHostingController(rootView: AgendaView(model: container.agenda!, maximumHeight: maximumHeight, onHeightChange: { [weak self] height in
            self?.resizeAgenda(height: height)
        }).modifier(ReviewLayoutModifier())); host.sizingOptions = []
        agendaPanel.contentViewController = host
        agendaPanel.backgroundColor = .windowBackgroundColor
        agendaPanel.setContentSize(NSSize(width: AppLayout.panelWidth, height: AppLayout.emptyHeight))
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closeAgenda() }
        }
        for name in [NSApplication.didBecomeActiveNotification, .NSCalendarDayChanged, NSNotification.Name.NSSystemTimeZoneDidChange] {
            notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.container.coordinator.notifyChange() }
            })
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.container.onboarding.shouldAutomaticallyPresent { self.showOnboarding(); return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--show-agenda") { self.showAgenda() }
            #endif
        }
    }
    @objc private func toggle() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp, let button = statusItem?.button {
            closeAgenda()
            let menu = NSMenu()
            let settings = menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ","); settings.target = self
            menu.addItem(.separator())
            let quit = menu.addItem(withTitle: "Quit Meetrail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); quit.target = NSApp
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        } else if agendaPanel.isVisible { closeAgenda() } else { showAgenda() }
    }
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
    func closeAgenda() { agendaPanel.orderOut(nil) }
    func showAgenda() {
        container.agenda.today(); resizeAgenda(height: agendaPanel.frame.height, anchorToStatus: true)
        NSApp.activate(ignoringOtherApps: true); agendaPanel.makeKeyAndOrderFront(nil)
    }
    private func resizeAgenda(height requestedHeight: CGFloat, anchorToStatus: Bool = false) {
        let visible = statusItem?.button?.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let height = min(max(1, requestedHeight), visible.height - AppSpacing.sm)
        let width = AppLayout.panelWidth
        var x = agendaPanel.frame.minX
        var top = agendaPanel.frame.maxY
        if anchorToStatus || agendaPanel.frame.isEmpty {
            let button = statusItem?.button
            let anchor = button?.window?.convertToScreen(button?.convert(button?.bounds ?? .zero, to: nil) ?? .zero) ?? visible
            x = max(visible.minX + AppSpacing.xs, min(anchor.midX - width / 2, visible.maxX - width - AppSpacing.xs))
            top = visible.maxY - AppSpacing.xs
        }
        agendaPanel.setFrame(NSRect(x: x, y: max(visible.minY, top - height), width: width, height: height), display: true)
    }
    func showAccounts() {
        closeAgenda(); container.accounts.refresh()
        if accountsWindow == nil {
            accountsWindow = makeWindow(title: "Accounts & Calendars", root: CalendarAccountsView(model: container.accounts))
        }
        NSApp.activate(ignoringOtherApps: true); accountsWindow?.makeKeyAndOrderFront(nil)
    }
    func showOnboarding() {
        closeAgenda()
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(title: "Welcome to Meetrail", root: OnboardingView(model: container.onboarding, onStageChange: { [weak self] stage in self?.resizeOnboarding(stage) }))
            onboardingWindow?.minSize = NSSize(width: 480, height: 240)
        }
        resizeOnboarding(container.onboarding.stage)
        NSApp.activate(ignoringOtherApps: true); onboardingWindow?.makeKeyAndOrderFront(nil)
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
        let host = NSHostingController(rootView: root); host.sizingOptions = []; window.contentViewController = host
        window.setContentSize(NSSize(width: AppLayout.onboardingWidth, height: AppLayout.onboardingHeight)); window.center(); return window
    }
    func showFloatingNote(_ id: NoteID) {
        do {
            if let panel = floatingPanels[id] { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil); return }
            let detail = try container.detail(id: id)
            let panel = AgendaPanel(contentRect: NSRect(x: 160, y: 180, width: AppLayout.notesWidth, height: AppLayout.detailHeight), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "Meetrail — \(detail.note.title)"; panel.level = .floating; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false; panel.minSize = NSSize(width: 320, height: 400); panel.delegate = self
            let host = NSHostingController(rootView: ScrollView { NoteEditorView(model: detail) }.tint(AppColors.accent)); host.sizingOptions = []
            panel.contentViewController = host; floatingPanels[id] = panel; NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
        } catch { let alert = NSAlert(); alert.messageText = error.localizedDescription; alert.runModal() }
    }
    func windowDidResignKey(_ notification: Notification) { if (notification.object as? NSWindow) === agendaPanel { closeAgenda() } }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === onboardingWindow { container.onboarding.windowClosed() }
        if let id = floatingPanels.first(where: { $0.value === window })?.key { floatingPanels.removeValue(forKey: id) }
    }
}

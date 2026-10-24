import AppKit
import SwiftUI

@MainActor final class AgendaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var panel: AgendaPanel?
    private var model: AgendaViewModel?
    private var outsideMonitor: Any?
    private var notificationTokens: [NSObjectProtocol] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Meetrail")
        item.button?.setAccessibilityLabel("Meetrail")
        item.button?.toolTip = "Meetrail — Your meetings. Your notes. All connected."
        item.button?.target = self; item.button?.action = #selector(toggle)
        let panel = AgendaPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 500), styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        self.panel = panel; panel.title = "Meetrail agenda"; panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true; panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.level = .floating; panel.hidesOnDeactivate = true; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        do {
            #if DEBUG
            let sample = ProcessInfo.processInfo.arguments.contains("--sample")
            let gateway: any CalendarGateway = sample ? SampleCalendarGateway(empty: ProcessInfo.processInfo.arguments.contains("--empty")) : EventKitCalendarGateway()
            #else
            let sample = false
            let gateway: any CalendarGateway = EventKitCalendarGateway()
            #endif
            let model = AgendaViewModel(calendar: gateway, notes: try NoteRepository(inMemory: sample), sample: sample, ai: AIServiceFactory.make())
            self.model = model
            let host = NSHostingController(rootView: AgendaView(model: model, close: { [weak panel] in panel?.orderOut(nil) }))
            host.sizingOptions = []
            model.onPresentationChange = { [weak self] in self?.resizePanel() }
            model.onPermissionResult = { [weak self] in
                self?.resizePanel(); NSApp.activate(ignoringOtherApps: true); self?.panel?.makeKeyAndOrderFront(nil)
            }
            panel.contentViewController = host
        } catch {
            panel.contentViewController = NSHostingController(rootView: VStack(alignment: .leading) {
                Text("Meetrail could not open its note store").font(.headline)
                Text("Existing data has not been replaced. \(error.localizedDescription)")
                Button("Quit") { NSApp.terminate(nil) }
            }.padding().frame(width: 360))
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.panel?.orderOut(nil) }
        }
        for name in [NSApplication.didBecomeActiveNotification, .NSCalendarDayChanged, NSNotification.Name.NSSystemTimeZoneDidChange] {
            notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.model?.refresh() }
            })
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-agenda") {
            DispatchQueue.main.async { [weak self] in self?.toggle() }
        }
        #endif
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { toggle() }; return true
    }
    @objc func toggle() {
        guard let panel, let button = statusItem?.button else { return }
        if panel.isVisible { panel.orderOut(nil); return }
        model?.today()
        let size = NSSize(width: 380, height: model?.panelHeight ?? 500)
        let screen = button.window?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let anchor = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? visible
        let height = min(max(size.height, 280), visible.height - 16)
        panel.setFrame(NSRect(x: max(visible.minX + 8, min(anchor.midX - 190, visible.maxX - 388)), y: visible.maxY - height - 8, width: 380, height: height), display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    private func resizePanel() {
        guard let panel else { return }
        let old = panel.frame
        let height = min(model?.panelHeight ?? 500, (panel.screen?.visibleFrame.height ?? 800) - 16)
        panel.setFrame(NSRect(x: old.minX, y: old.maxY - height, width: 380, height: height), display: true)
    }
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == panel { panel?.orderOut(nil) }
    }
}

@MainActor final class FloatingNotesController: NSObject, NSWindowDelegate {
    static let shared = FloatingNotesController()
    private var panels: [UUID: NSPanel] = [:]
    func show(note: MeetingNote, meeting: Meeting?, model: AgendaViewModel) {
        if let panel = panels[note.id] { panel.makeKeyAndOrderFront(nil); return }
        let panel = NSPanel(contentRect: NSRect(x: 160, y: 180, width: 380, height: 620), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "Meetrail — \(note.title)"; panel.level = .floating; panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false; panel.delegate = self
        panel.minSize = NSSize(width: 360, height: 480)
        panel.contentViewController = NSHostingController(rootView: ScrollView { NoteEditorView(note: note, meeting: meeting, model: model, floating: true) }.tint(MeetrailStyle.accent))
        panels[note.id] = panel; panel.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, let id = panels.first(where: { $0.value === panel })?.key else { return }
        panels.removeValue(forKey: id)
    }
}

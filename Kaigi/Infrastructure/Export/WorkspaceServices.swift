import AppKit
import UniformTypeIdentifiers

@MainActor struct WorkspaceLinkOpener: LinkOpening {
    func open(_ url: URL) throws {
        guard NSWorkspace.shared.open(url) else { throw RefinementFailure(message: "macOS could not open this link. Check your default browser or meeting application.") }
    }
}
@MainActor struct MarkdownExporter {
    func export(_ document: MarkdownDocument) async throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = document.filename
        let response = await withCheckedContinuation { continuation in panel.begin { continuation.resume(returning: $0) } }
        guard response == .OK, let url = panel.url else { return }
        try document.text.write(to: url, atomically: true, encoding: .utf8)
    }
}

@MainActor struct WorkspacePermissionSettings: PermissionSettingsOpening {
    func openCalendarSettings() throws {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"), NSWorkspace.shared.open(url) else {
            throw RefinementFailure(message: "Open System Settings → Privacy & Security → Calendars to allow access.")
        }
    }
}

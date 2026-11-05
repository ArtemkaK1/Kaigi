import AppKit
import SwiftUI

/// A native checkbox whose mixed state is supplied by its owner, never cycled into.
struct MixedStateCheckbox: NSViewRepresentable {
    let title: String
    let accessibilityLabel: String
    let isOn: Bool
    let isMixed: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.isEnabled) private var enabled
    @ScaledMetric(relativeTo: .body) private var fontSize = AppTextRole.body.baseSize

    func makeNSView(context: Context) -> NativeCheckbox {
        let button = NativeCheckbox(checkboxWithTitle: title, target: context.coordinator, action: #selector(Coordinator.activate(_:)))
        button.setButtonType(.switch)
        button.allowsMixedState = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NativeCheckbox, context: Context) {
        context.coordinator.action = action
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: max(fontSize, AppTextRole.body.baseSize * AppTypography.scale(for: textSize))),
            .foregroundColor: NSColor(enabled ? AppColors.primary : AppColors.disabled)
        ])
        button.contentTintColor = NSColor(AppColors.accentFill)
        button.bezelColor = NSColor(AppColors.accentFill)
        button.state = isMixed ? .mixed : isOn ? .on : .off
        button.isEnabled = enabled
        button.setAccessibilityLabel(accessibilityLabel)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NativeCheckbox, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) { self.action = action }

        @objc func activate(_ sender: NativeCheckbox) {
            sender.focusForActivation()
            action()
        }
    }

    final class NativeCheckbox: NSButton {
        private var handlingMouseDown = false
        private var showsKeyboardFocus = false
        override var acceptsFirstResponder: Bool { true }
        override var canBecomeKeyView: Bool { isEnabled && !isHiddenOrHasHiddenAncestor && window != nil }

        override func mouseDown(with event: NSEvent) {
            handlingMouseDown = true
            defer { handlingMouseDown = false }
            updateFocusRing(forMouse: true)
            super.mouseDown(with: event)
        }

        override func becomeFirstResponder() -> Bool {
            // Accessibility/programmatic focus keeps native feedback; only mouse focus is quiet.
            let accepted = super.becomeFirstResponder()
            if accepted { updateFocusRing(forMouse: handlingMouseDown) }
            return accepted
        }

        override func keyDown(with event: NSEvent) {
            // Space must reveal focus even when a preceding mouse click already focused us.
            updateFocusRing(forMouse: false)
            super.keyDown(with: event)
        }

        func focusForActivation() {
            window?.makeFirstResponder(self)
            updateFocusRing(forMouse: handlingMouseDown)
        }

        private func updateFocusRing(forMouse: Bool) {
            showsKeyboardFocus = !forMouse
            // Draw the native mask explicitly so keyboard feedback also works when
            // macOS Full Keyboard Access is off, without restoring the mouse ring.
            focusRingType = .none
            cell?.showsFirstResponder = false
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard showsKeyboardFocus, window?.isKeyWindow == true, window?.firstResponder === self else { return }
            NSGraphicsContext.saveGraphicsState()
            NSFocusRingPlacement.only.set()
            cell?.drawFocusRingMask(withFrame: bounds, in: self)
            NSGraphicsContext.restoreGraphicsState()
        }

        override func resignFirstResponder() -> Bool {
            let accepted = super.resignFirstResponder()
            if accepted {
                showsKeyboardFocus = false
                needsDisplay = true
            }
            return accepted
        }

        override func setNextState() {
            state = state == .on ? .off : .on
        }
    }
}

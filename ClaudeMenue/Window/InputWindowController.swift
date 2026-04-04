import AppKit
import SwiftUI

private class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class InputWindowController: NSWindowController {
    var onSubmit: ((String) async -> String)?

    init() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 220),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        super.init(window: panel)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func showCentered() {
        let inputView = InputView(
            onSubmit: { [weak self] text in
                await self?.onSubmit?(text) ?? "Nicht konfiguriert"
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        window?.contentView = NSHostingView(rootView: inputView)

        guard let screen = NSScreen.main, let window = window else { return }
        let x = screen.visibleFrame.midX - window.frame.width / 2
        let y = screen.visibleFrame.midY - window.frame.height / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
    }
}

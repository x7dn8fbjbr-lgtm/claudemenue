import AppKit

class MenuBarManager {
    private var statusItem: NSStatusItem?
    private let windowController: InputWindowController
    weak var settingsWindowController: SettingsWindowController?

    init(windowController: InputWindowController) {
        self.windowController = windowController
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(loading: false)

        guard let button = statusItem?.button else { return }
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func setLoading(_ loading: Bool) {
        if Thread.isMainThread {
            setIcon(loading: loading)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.setIcon(loading: loading)
            }
        }
    }

    private func setIcon(loading: Bool) {
        let symbolName = loading ? "ellipsis.circle" : "bubble.left.and.text.bubble.right"
        statusItem?.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ClaudeMenue")
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWindow()
        }
    }

    private func toggleWindow() {
        if windowController.window?.isVisible == true {
            windowController.close()
        } else {
            windowController.showCentered()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Einstellungen…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Beenden", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSettings() {
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

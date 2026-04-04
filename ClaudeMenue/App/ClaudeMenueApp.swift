import SwiftUI

@main
struct ClaudeMenueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var hotKeyManager: HotKeyManager?
    private var windowController: InputWindowController?
    private var claudeService: ClaudeService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NotificationService.shared.requestPermission()

        let windowCtrl = InputWindowController()
        self.windowController = windowCtrl

        let menuBar = MenuBarManager(windowController: windowCtrl)
        menuBar.settingsWindowController = SettingsWindowController.shared
        menuBar.setup()
        self.menuBarManager = menuBar

        let hotKey = HotKeyManager()
        hotKey.onHotKey = { [weak windowCtrl] in
            windowCtrl?.showCentered()
        }
        hotKey.start()
        self.hotKeyManager = hotKey

        rebuildServices()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsSaved),
            name: .claudeMenueSettingsSaved,
            object: nil
        )

        if !SettingsStore.shared.isConfigured {
            SettingsWindowController.shared.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func settingsSaved() {
        rebuildServices()
    }

    func rebuildServices() {
        guard let apiKey = SettingsStore.shared.anthropicApiKey,
              let todoistToken = SettingsStore.shared.todoistApiToken else { return }

        let todoistService = TodoistService(token: todoistToken)
        let service = ClaudeService(apiKey: apiKey, todoistService: todoistService)
        self.claudeService = service  // strong reference — prevents deallocation

        windowController?.onSubmit = { [weak self] text in
            guard let claudeService = self?.claudeService else { return "Nicht konfiguriert" }
            return await claudeService.process(input: text) { [weak self] loading in
                self?.menuBarManager?.setLoading(loading)
            }
        }
    }
}

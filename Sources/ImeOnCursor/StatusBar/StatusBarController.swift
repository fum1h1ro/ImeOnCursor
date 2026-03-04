import AppKit
import SwiftUI

final class StatusBarController: ObservableObject {
    @Published private(set) var knownSources: [InputSourceInfo] = []

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var settingsController: NSHostingController<SettingsView>?
    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        knownSources = InputSourceInfo.allSelectable()
        setupStatusItem()
    }

    func registerSource(_ source: InputSourceInfo) {
        guard !knownSources.contains(source) else { return }
        knownSources.append(source)
        updateSettingsViewIfOpen()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ImeOnCursor")

        let menu = NSMenu()
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit ImeOnCursor", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu
    }

    @objc private func openPreferences() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(store: store, knownSources: knownSources)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "ImeOnCursor Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 420, height: 300))
        window.center()

        // LSUIElementアプリがキーウィンドウを持つには一時的に.regularが必要
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // ウィンドウを閉じたらDockアイコンを非表示に戻す
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            NSApp.setActivationPolicy(.accessory)
            self?.settingsWindow = nil
            self?.settingsController = nil
        }

        settingsWindow = window
        settingsController = controller
    }

    private func updateSettingsViewIfOpen() {
        guard let controller = settingsController,
              let window = settingsWindow, window.isVisible else { return }
        controller.rootView = SettingsView(store: store, knownSources: knownSources)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

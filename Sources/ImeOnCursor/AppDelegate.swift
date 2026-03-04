import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore!
    private var inputSourceObserver: InputSourceObserver!
    private var overlayController: OverlayWindowController!
    private var statusBarController: StatusBarController!

    private var cancellables = Set<AnyCancellable>()
    private var axCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore.shared
        inputSourceObserver = InputSourceObserver()
        overlayController = OverlayWindowController()
        statusBarController = StatusBarController(store: settingsStore)

        checkAccessibilityPermission()
        bindInputSourceChanges()
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        if AXIsProcessTrustedWithOptions(options) { return }

        showAccessibilityAlert()
        startAxPolling()
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "アクセシビリティの許可が必要です"
        alert.informativeText = """
            ImeOnCursor はテキスト入力カーソル位置を取得するためにアクセシビリティの権限が必要です。

            システム設定 > プライバシーとセキュリティ > アクセシビリティ
            に移動して ImeOnCursor を許可してください。
            許可後は自動的に動作を開始します。
            """
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "後で")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    private func startAxPolling() {
        axCheckTimer?.invalidate()
        axCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.axCheckTimer = nil
            }
        }
    }

    // MARK: - Input Source Changes

    private func bindInputSourceChanges() {
        inputSourceObserver.currentSource
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sourceInfo in
                self?.handleSourceChange(sourceInfo)
            }
            .store(in: &cancellables)
    }

    private func handleSourceChange(_ sourceInfo: InputSourceInfo) {
        statusBarController.registerSource(sourceInfo)
        let mode = settingsStore.mode(for: sourceInfo.id)
        overlayController.show(source: sourceInfo, mode: mode)
    }
}

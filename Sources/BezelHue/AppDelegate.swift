import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore!
    private var inputSourceObserver: InputSourceObserver!
    private var bandController: BandWindowController!
    private var statusBarController: StatusBarController!

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore.shared
        inputSourceObserver = InputSourceObserver()
        bandController = BandWindowController(
            positions: settingsStore.bandPositions,
            thickness: settingsStore.bandThickness
        )
        statusBarController = StatusBarController(store: settingsStore)

        bindInputSourceChanges()
        bindBandEnabled()
        bindBandLayout()
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

    private func bindBandEnabled() {
        settingsStore.$bandEnabled
            .sink { [weak self] enabled in
                if !enabled { self?.bandController.hideAll() }
            }
            .store(in: &cancellables)
    }

    private func bindBandLayout() {
        settingsStore.$bandPositions
            .combineLatest(settingsStore.$bandThickness)
            .dropFirst()
            .sink { [weak self] positions, thickness in
                self?.bandController.reconfigure(positions: positions, thickness: thickness)
            }
            .store(in: &cancellables)
    }

    private func handleSourceChange(_ sourceInfo: InputSourceInfo) {
        statusBarController.registerSource(sourceInfo)
        guard settingsStore.bandEnabled else { return }
        let mode = settingsStore.mode(for: sourceInfo.id)
        let color = settingsStore.bandColor(for: sourceInfo.id)
            ?? BandWindowController.autoColor(for: sourceInfo.id)
        bandController.show(color: color, mode: mode)
    }
}

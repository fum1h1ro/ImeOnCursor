import AppKit

enum BandPosition: String, CaseIterable, Codable {
    case top, bottom, left, right

    var label: String {
        switch self {
        case .top:    return "上端（メニューバー直下）"
        case .bottom: return "下端"
        case .left:   return "左端"
        case .right:  return "右端"
        }
    }
}

final class BandWindowController {
    private struct PanelEntry {
        let panel: NSPanel
    }

    private var panelEntries: [PanelEntry] = []
    private var positions: Set<BandPosition>
    private var thickness: CGFloat
    private var currentCGColor: CGColor = NSColor.systemBlue.cgColor
    private var hideTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init(positions: Set<BandPosition>, thickness: CGFloat) {
        self.positions = positions
        self.thickness = thickness
        setupPanels()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.screensChanged()
        }
    }

    deinit {
        if let obs = screenObserver { NotificationCenter.default.removeObserver(obs) }
        hideAll()
    }

    // MARK: - Public API

    func reconfigure(positions: Set<BandPosition>, thickness: CGFloat) {
        let wasVisible = panelEntries.first(where: { $0.panel.isVisible }) != nil
        self.positions = positions
        self.thickness = thickness
        setupPanels()
        if wasVisible { showAll() }
    }

    func show(color: NSColor, mode: DisplayMode) {
        currentCGColor = color.withAlphaComponent(0.85).cgColor
        updateColors()

        switch mode {
        case .hidden:
            hideAll()
        case .timedShow(let seconds):
            showAll()
            scheduleHide(after: seconds)
        case .alwaysShow:
            cancelHideTimer()
            showAll()
        }
    }

    func hideAll() {
        cancelHideTimer()
        panelEntries.forEach { $0.panel.orderOut(nil) }
    }

    // MARK: - Panel Management

    private func setupPanels() {
        panelEntries.forEach { $0.panel.orderOut(nil) }
        panelEntries = NSScreen.screens.flatMap { screen in
            positions.map { position in
                PanelEntry(panel: makePanel(frame: frame(for: position, on: screen)))
            }
        }
    }

    private func frame(for position: BandPosition, on screen: NSScreen) -> NSRect {
        let vf = screen.visibleFrame
        let sf = screen.frame
        switch position {
        case .top:
            return NSRect(x: sf.minX, y: vf.maxY - thickness, width: sf.width, height: thickness)
        case .bottom:
            return NSRect(x: sf.minX, y: vf.minY, width: sf.width, height: thickness)
        case .left:
            return NSRect(x: sf.minX, y: vf.minY, width: thickness, height: vf.height)
        case .right:
            return NSRect(x: sf.maxX - thickness, y: vf.minY, width: thickness, height: vf.height)
        }
    }

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.hasShadow = false
        let colorView = ColorView(frame: NSRect(origin: .zero, size: frame.size))
        colorView.update(currentCGColor)
        panel.contentView = colorView
        return panel
    }

    private func updateColors() {
        panelEntries.forEach { ($0.panel.contentView as? ColorView)?.update(currentCGColor) }
    }

    private func showAll() {
        panelEntries.forEach { $0.panel.orderFrontRegardless() }
    }

    private func scheduleHide(after seconds: Double) {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.hideAll()
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func screensChanged() {
        let wasVisible = panelEntries.first(where: { $0.panel.isVisible }) != nil
        setupPanels()
        if wasVisible { showAll() }
    }

    // MARK: - Auto Color

    static func autoColor(for sourceID: String) -> NSColor {
        var hash = 5381
        for scalar in sourceID.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        let hue = CGFloat((hash & 0x7FFF) % 360) / 360.0
        return NSColor(hue: hue, saturation: 0.85, brightness: 0.9, alpha: 1.0)
    }
}

// MARK: - Helpers

private final class ColorView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(_ cgColor: CGColor) {
        layer?.backgroundColor = cgColor
    }
}

extension NSColor {
    var hexRGBString: String {
        let rgb = usingColorSpace(.sRGB) ?? self
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }

    convenience init?(hexRGB: String) {
        var s = hexRGB
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1.0
        )
    }
}

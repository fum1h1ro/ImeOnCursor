import AppKit
import SwiftUI

final class OverlayWindowController {
    private var panel: NSPanel?
    private let viewModel = OverlayViewModel()
    private var caretTimer: Timer?
    private var hideTimer: Timer?

    private let overlaySize = CGSize(width: 48, height: 48)
    private let caretOffsetX: CGFloat = 4
    private let caretOffsetY: CGFloat = 4

    init() {
        setupPanel()
    }

    deinit {
        stopCaretTracking()
        panel?.orderOut(nil)
    }

    // MARK: - Public API

    func show(source: InputSourceInfo, mode: DisplayMode) {
        viewModel.sourceInfo = source

        switch mode {
        case .hidden:
            hide()
            stopCaretTracking()

        case .timedShow(let seconds):
            stopCaretTracking()
            if let rect = caretRect() {
                position(near: rect)
                panel?.orderFrontRegardless()
                scheduleHide(after: seconds)
            } else {
                hide()
            }

        case .alwaysShow:
            cancelHideTimer()
            startCaretTracking()
        }
    }

    func hide() {
        cancelHideTimer()
        panel?.orderOut(nil)
    }

    // MARK: - Panel Setup

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: overlaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hasShadow = false

        let rootView = OverlayView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: overlaySize)
        panel.contentView = hostingView

        self.panel = panel
    }

    // MARK: - Caret Position (Accessibility)

    private func caretRect() -> NSRect? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        ) == .success, let focusedRef else { return nil }
        let focused = focusedRef as! AXUIElement

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused, kAXSelectedTextRangeAttribute as CFString, &rangeRef
        ) == .success else { return nil }

        // 1st try: 選択範囲の正確なRect
        if let rangeRef {
            var boundsRef: CFTypeRef?
            let err = AXUIElementCopyParameterizedAttributeValue(
                focused, kAXBoundsForRangeParameterizedAttribute as CFString, rangeRef, &boundsRef
            )
            if err == .success, let boundsRef,
               CFGetTypeID(boundsRef) == AXValueGetTypeID() {
                let boundsValue = boundsRef as! AXValue
                var axRect = CGRect.zero
                if AXValueGetValue(boundsValue, .cgRect, &axRect),
                   !axRect.isEmpty, axRect.width < 10_000, axRect.height < 10_000 {
                    return axToCocoaRect(axRect)
                }
            }
        }

        // 2nd try: 要素のフレームで代替
        var frameRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, "AXFrame" as CFString, &frameRef) == .success,
           let frameRef, CFGetTypeID(frameRef) == AXValueGetTypeID() {
            let frameValue = frameRef as! AXValue
            var axRect = CGRect.zero
            if AXValueGetValue(frameValue, .cgRect, &axRect), !axRect.isEmpty {
                return axToCocoaRect(axRect)
            }
        }

        return nil
    }

    private func axToCocoaRect(_ axRect: CGRect) -> NSRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(
            x: axRect.minX,
            y: primaryScreenHeight - axRect.maxY,
            width: axRect.width,
            height: axRect.height
        )
    }

    private func position(near caretCocoa: NSRect) {
        guard let panel else { return }

        var x = caretCocoa.minX + caretOffsetX
        var y = caretCocoa.minY - overlaySize.height - caretOffsetY

        let caretMid = NSPoint(x: caretCocoa.midX, y: caretCocoa.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(caretMid) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            x = max(frame.minX, min(x, frame.maxX - overlaySize.width))
            y = max(frame.minY, min(y, frame.maxY - overlaySize.height))
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Caret Tracking (alwaysShow)

    private func startCaretTracking() {
        guard caretTimer == nil else { return }
        caretTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let rect = self.caretRect() {
                self.position(near: rect)
                if self.panel?.isVisible == false {
                    self.panel?.orderFrontRegardless()
                }
            } else if self.panel?.isVisible == true {
                self.panel?.orderOut(nil)
            }
        }
    }

    private func stopCaretTracking() {
        caretTimer?.invalidate()
        caretTimer = nil
    }

    // MARK: - Hide Timer

    private func scheduleHide(after seconds: Double) {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
}

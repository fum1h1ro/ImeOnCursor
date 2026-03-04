import AppKit
import Carbon.HIToolbox

struct InputSourceInfo: Equatable {
    let id: String
    let localizedName: String
    let icon: NSImage?

    static func == (lhs: InputSourceInfo, rhs: InputSourceInfo) -> Bool {
        lhs.id == rhs.id
    }
}

extension InputSourceInfo {
    static func current() -> InputSourceInfo? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return InputSourceInfo(from: source)
    }

    /// 現在ユーザーが有効にしている、選択可能なキーボードInputSourceを全て返す
    static func allSelectable() -> [InputSourceInfo] {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable: true,
        ]
        guard let listRef = TISCreateInputSourceList(filter as CFDictionary, false) else {
            return []
        }
        let list = listRef.takeRetainedValue()
        return (0..<CFArrayGetCount(list)).compactMap { i in
            guard let ptr = CFArrayGetValueAtIndex(list, i) else { return nil }
            let source = Unmanaged<TISInputSource>.fromOpaque(ptr).takeUnretainedValue()
            return InputSourceInfo(from: source)
        }
    }

    init?(from source: TISInputSource) {
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

        let localizedName: String
        if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            localizedName = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        } else {
            localizedName = id
        }

        let icon = InputSourceInfo.icon(from: source, fallbackName: localizedName)

        self.id = id
        self.localizedName = localizedName
        self.icon = icon
    }

    private static func icon(from source: TISInputSource, fallbackName: String) -> NSImage? {
        // 1. Try kTISPropertyIconImageURL
        if let urlPtr = TISGetInputSourceProperty(source, kTISPropertyIconImageURL) {
            let url = Unmanaged<CFURL>.fromOpaque(urlPtr).takeUnretainedValue() as URL
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        // 2. Fallback: text-based icon with first 2 chars of localized name
        return textIcon(for: fallbackName)
    }

    private static func textIcon(for name: String) -> NSImage {
        let text = String(name.prefix(2))
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)

        image.lockFocus()

        // Background
        NSColor.systemBlue.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 8, yRadius: 8).fill()

        // Text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.white
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrString.draw(in: textRect)

        image.unlockFocus()
        return image
    }
}

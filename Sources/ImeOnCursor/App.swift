import AppKit

private let _appDelegate = AppDelegate()

// Entry point - must be in a file named other than main.swift when using @main,
// or we can set NSPrincipalClass in Info.plist. Here we use the @main attribute.
@main
struct ImeOnCursorApp {
    static func main() {
        let app = NSApplication.shared
        app.delegate = _appDelegate
        app.run()
    }
}

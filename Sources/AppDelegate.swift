import AppKit
import SwiftUI
import Combine

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var signInInFlight = false
    private var currentState: LoadState = .signedOut

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // no Dock icon
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance: if another copy is already running (e.g. a login-item
        // launch plus a manual one), quit so we don't double the request rate.
        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.fk.ClaudeUsage")
            .filter { $0 != .current }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        installEditMenu()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: UsageView(model: model, onQuit: { NSApp.terminate(nil) })
        )

        // Drive the menu bar from model changes…
        model.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.currentState = state
                self?.render()
            }
            .store(in: &cancellables)

        // …on every clock tick, so the compact reset countdown stays live
        // between data fetches instead of freezing at the last fetch time.
        model.$clock
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.render() }
            .store(in: &cancellables)

        // …and re-render when the weekly-in-bar preference changes.
        SettingsStore.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in DispatchQueue.main.async { self?.render() } }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self, selector: #selector(startSignIn), name: .startSignIn, object: nil)

        currentState = model.state
        render()
        model.start()
    }

    /// Agent apps (LSUIElement) have no menu bar, so the standard Cut/Copy/Paste
    /// key equivalents aren't routed through the responder chain. Installing an
    /// Edit menu restores ⌘X/⌘C/⌘V/⌘A in text fields like the sign-in dialog.
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu bar rendering

    private func render() {
        guard let button = statusItem.button else { return }
        let content = MenuBarRenderer.content(for: currentState, settings: SettingsStore.shared)
        button.image = content.image
        button.imagePosition = content.image == nil ? .noImage : .imageLeft
        button.attributedTitle = content.title
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            if model.isSignedIn { model.refresh() }
        }
    }

    // MARK: - Sign in

    @objc private func startSignIn() {
        guard !signInInFlight else { return }
        signInInFlight = true
        popover.performClose(nil)
        model.beginSignIn()
        // Give the browser a moment to open, then prompt for the code.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.promptForCode()
        }
    }

    private func promptForCode() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Finish signing in"
        alert.informativeText = "Your browser opened the Claude authorization page. After you approve, copy the code shown and paste it here."
        alert.addButton(withTitle: "Sign in")
        alert.addButton(withTitle: "Cancel")

        let field = PasteableTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Paste code here"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            signInInFlight = false
            return
        }
        let code = field.stringValue
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            signInInFlight = false
            showError("No code entered.")
            return
        }
        Task { @MainActor in
            let error = await model.completeSignIn(code: code)
            signInInFlight = false
            if let error { showError(error) }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Sign-in failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/// A text field that handles ⌘X/⌘C/⌘V/⌘A itself, so paste works inside the
/// sign-in dialog even though this is a menu-bar-only app with no menu bar.
final class PasteableTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        let action: Selector?
        switch key {
        case "x": action = #selector(NSText.cut(_:))
        case "c": action = #selector(NSText.copy(_:))
        case "v": action = #selector(NSText.paste(_:))
        case "a": action = #selector(NSText.selectAll(_:))
        default:  action = nil
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

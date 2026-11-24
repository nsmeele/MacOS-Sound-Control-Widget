import AppKit
import ServiceManagement
import WidgetKit

/// Invisible background agent (LSUIElement). Its only job is to refresh the widget
/// when audio devices come and go or the output is changed elsewhere.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingReload: DispatchWorkItem?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AudioDevices.observeChanges { [weak self] in self?.scheduleReload() }
        try? SMAppService.mainApp.register()
        WidgetCenter.shared.reloadAllTimelines()
        showWelcomeOnce()
    }

    /// Device changes arrive in bursts; coalesce them into one reload.
    private func scheduleReload() {
        pendingReload?.cancel()
        let work = DispatchWorkItem { WidgetCenter.shared.reloadAllTimelines() }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func showWelcomeOnce() {
        let key = "didShowWelcome"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Audio Switcher is running in the background"
        alert.informativeText = """
        Right-click the desktop, choose ‘Edit Widgets…’ (or open Notification Center) \
        and add the ‘Sound Output’ widget.

        The app now opens automatically when you log in, so the widget stays up to date \
        when you connect headphones, for example.
        """
        alert.runModal()
    }
}

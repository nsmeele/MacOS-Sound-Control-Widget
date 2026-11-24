import AppKit
import ServiceManagement
import WidgetKit

/// Invisible background agent (LSUIElement). It carries out the widget's button presses
/// (the sandboxed widget can't change audio settings itself) and refreshes the widget
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
        listenForWidgetRequests()
        try? SMAppService.mainApp.register()
        WidgetCenter.shared.reloadAllTimelines()
        showWelcomeOnce()
    }

    // MARK: - Widget requests

    private func listenForWidgetRequests() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(selectOutput(_:)), name: AppMessage.selectOutput,
                           object: nil, suspensionBehavior: .deliverImmediately)
        center.addObserver(self, selector: #selector(setMuted(_:)), name: AppMessage.setMuted,
                           object: nil, suspensionBehavior: .deliverImmediately)
        center.addObserver(self, selector: #selector(stepVolume(_:)), name: AppMessage.stepVolume,
                           object: nil, suspensionBehavior: .deliverImmediately)
    }

    // The Core Audio listeners above notice these changes and reload the widget.

    @objc private func selectOutput(_ notification: Notification) {
        guard let uid = notification.object as? String else { return }
        AudioDevices.setDefaultOutput(uid: uid)
    }

    @objc private func setMuted(_ notification: Notification) {
        guard let value = notification.object as? String else { return }
        AudioDevices.setMuted(value == "1")
    }

    @objc private func stepVolume(_ notification: Notification) {
        guard let value = notification.object as? String else { return }
        AudioDevices.stepVolume(up: value == "up")
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
        alert.messageText = "Sound Control is running in the background"
        alert.informativeText = """
        Right-click the desktop, choose ‘Edit Widgets…’ (or open Notification Center) \
        and add the ‘Sound Control’ widget.

        The app now opens automatically when you log in, so the widget stays up to date \
        when you connect headphones, for example.
        """
        alert.runModal()
    }
}

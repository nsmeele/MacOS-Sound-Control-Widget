import Foundation

/// The widget runs sandboxed and isn't allowed to change system audio settings,
/// so it asks the unsandboxed background app to do it.
///
/// Sandboxed processes may post distributed notifications, but without a `userInfo`
/// dictionary, so the value travels as the notification's `object` string.
enum AppMessage {
    static let selectOutput = Notification.Name("io.github.nsmeele.soundcontrol.selectOutput")
    static let setMuted = Notification.Name("io.github.nsmeele.soundcontrol.setMuted")
    static let stepVolume = Notification.Name("io.github.nsmeele.soundcontrol.stepVolume")

    static func post(_ name: Notification.Name, value: String) {
        DistributedNotificationCenter.default().postNotificationName(
            name, object: value, userInfo: nil, deliverImmediately: true
        )
    }
}

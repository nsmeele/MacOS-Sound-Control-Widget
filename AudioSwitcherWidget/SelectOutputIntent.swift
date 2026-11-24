import AppIntents

struct SelectOutputIntent: AppIntent {
    static let title: LocalizedStringResource = "Select Sound Output"
    static let isDiscoverable = false

    @Parameter(title: "Device UID")
    var uid: String

    init() {}

    init(uid: String) {
        self.uid = uid
    }

    func perform() async throws -> some IntentResult {
        // The background app does the actual switch and then reloads the widget.
        AppMessage.post(AppMessage.selectOutput, value: uid)
        return .result()
    }
}

struct SetMuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute Sound Output"
    static let isDiscoverable = false

    @Parameter(title: "Muted")
    var muted: Bool

    init() {}

    init(muted: Bool) {
        self.muted = muted
    }

    func perform() async throws -> some IntentResult {
        AppMessage.post(AppMessage.setMuted, value: muted ? "1" : "0")
        return .result()
    }
}

struct StepVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Change Volume"
    static let isDiscoverable = false

    @Parameter(title: "Louder")
    var up: Bool

    init() {}

    init(up: Bool) {
        self.up = up
    }

    func perform() async throws -> some IntentResult {
        AppMessage.post(AppMessage.stepVolume, value: up ? "up" : "down")
        return .result()
    }
}

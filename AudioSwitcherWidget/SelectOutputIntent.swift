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
        AudioDevices.setDefaultOutput(uid: uid)
        // WidgetKit reloads the widget automatically after an interactive intent.
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
        AudioDevices.setMuted(muted)
        return .result()
    }
}

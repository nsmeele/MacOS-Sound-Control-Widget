import CoreAudio
import Foundation

struct AudioOutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transport: UInt32

    var symbol: String {
        let lowered = name.lowercased()
        if lowered.contains("headphone") || lowered.contains("koptelefoon") || lowered.contains("airpods") {
            return "headphones"
        }
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "headphones"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "display"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt:
            return "hifispeaker"
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate:
            return "waveform"
        default:
            return "speaker.wave.2"
        }
    }
}

enum AudioDevices {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    /// All devices that can play audio, sorted by name.
    static func outputDevices() -> [AudioOutputDevice] {
        allDeviceIDs()
            .filter { hasOutputStreams($0) && !isHidden($0) }
            .compactMap { id in
                guard let uid = string(kAudioDevicePropertyDeviceUID, of: id),
                      let name = string(kAudioObjectPropertyName, of: id) else { return nil }
                return AudioOutputDevice(id: id, uid: uid, name: name, transport: uint32(kAudioDevicePropertyTransportType, of: id) ?? 0)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func defaultOutputID() -> AudioDeviceID? {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    /// Makes the device with this UID the system output, exactly as picking it in System Settings does.
    @discardableResult
    static func setDefaultOutput(uid: String) -> Bool {
        guard let device = outputDevices().first(where: { $0.uid == uid }) else { return false }
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = device.id
        return AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id) == noErr
    }

    // MARK: - Mute

    /// Whether the current output device can be muted at all (HDMI outputs often can't).
    static var canMute: Bool {
        guard let id = defaultOutputID() else { return false }
        return !muteElements(of: id).isEmpty
    }

    static var isMuted: Bool {
        guard let id = defaultOutputID() else { return false }
        return muteElements(of: id).contains {
            uint32(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, element: $0, of: id) == 1
        }
    }

    /// Mutes or unmutes the current output device.
    @discardableResult
    static func setMuted(_ muted: Bool) -> Bool {
        guard let id = defaultOutputID() else { return false }
        let elements = muteElements(of: id)
        guard !elements.isEmpty else { return false }
        var value: UInt32 = muted ? 1 : 0
        return elements.allSatisfy { element in
            var addr = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, element: element)
            return AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
        }
    }

    /// Most devices expose mute on the main element; some only per channel (left/right).
    private static func muteElements(of id: AudioDeviceID) -> [AudioObjectPropertyElement] {
        func settable(_ element: AudioObjectPropertyElement) -> Bool {
            var addr = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, element: element)
            var isSettable: DarwinBoolean = false
            return AudioObjectHasProperty(id, &addr)
                && AudioObjectIsPropertySettable(id, &addr, &isSettable) == noErr
                && isSettable.boolValue
        }
        if settable(kAudioObjectPropertyElementMain) { return [kAudioObjectPropertyElementMain] }
        return [1, 2].filter(settable)
    }

    // MARK: - Change notifications

    /// Calls `handler` on the main queue whenever devices appear/disappear, the default output
    /// changes, or the default output is muted/unmuted.
    static func observeChanges(_ handler: @escaping () -> Void) {
        var observedForMute = Set<AudioDeviceID>()

        func observeMuteOnDefaultDevice() {
            guard let id = defaultOutputID(), observedForMute.insert(id).inserted else { return }
            for element in muteElements(of: id) {
                var addr = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, element: element)
                AudioObjectAddPropertyListenerBlock(id, &addr, .main) { _, _ in handler() }
            }
        }

        observeMuteOnDefaultDevice()
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDevices] {
            var addr = address(selector)
            AudioObjectAddPropertyListenerBlock(system, &addr, .main) { _, _ in
                observeMuteOnDefaultDevice()
                handler()
            }
        }
    }

    // MARK: - Property helpers

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
    }

    private static func isHidden(_ id: AudioDeviceID) -> Bool {
        (uint32(kAudioDevicePropertyIsHidden, of: id) ?? 0) != 0
    }

    private static func uint32(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        of id: AudioDeviceID
    ) -> UInt32? {
        var addr = address(selector, scope: scope, element: element)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func string(_ selector: AudioObjectPropertySelector, of id: AudioDeviceID) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

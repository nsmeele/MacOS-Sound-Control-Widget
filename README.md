# Sound Control Widget

A macOS widget for switching your sound output, changing the volume and muting – each with a single click, no trip to System Settings required.

- **Output**: every output you can pick in System Settings (built-in speakers, headphones, USB, displays, AirPlay…) is a button; the active one gets a tick.
- **Volume**: − and + buttons with a volume bar, in the same steps as the keyboard volume keys. WidgetKit doesn't support sliders, hence the buttons.
- **Mute**: mutes or unmutes the current output.
- **Stays in sync**: changes made elsewhere (keyboard keys, Control Center, plugging in headphones) show up in the widget straight away.
- Small, medium and large widget sizes.

Controls the current output can't handle are greyed out – HDMI and DisplayPort outputs, for instance, often have no volume or mute control.

### What fits

Widgets can't scroll, so the number of devices shown is limited by the widget's size: 3 in the small widget, 6 in the medium one (two columns) and 8 in the large one. The active device is always shown.

## Installation

Download the latest `.dmg` from [Releases](../../releases/latest) and follow the steps in the release notes.

The app isn't notarised by Apple, so the first time you open it macOS will block it. Allow it once via **System Settings → Privacy & Security → Open Anyway**.

Requires macOS 14 Sonoma or later. Runs natively on both Apple silicon and Intel Macs.

## Building from source

1. Clone the repo and open `AudioSwitcher.xcodeproj` (Xcode 16 or later).
2. Select the **AudioSwitcher** scheme (not *AudioSwitcherWidgetExtension*) and **My Mac**, then press **⌘R**.
3. Right-click the desktop, choose **Edit Widgets…** and add **Sound Control**.

The project is set to *Sign to Run Locally*, so it builds without an Apple developer account. If the widget doesn't appear in the gallery, select your own team (a free Personal Team is fine) under **Signing & Capabilities** for both targets.

### Releasing

Push a version tag and GitHub Actions builds a universal DMG (Apple silicon and Intel) and publishes the release. The build fails if the app or the widget is missing either architecture.

```sh
git tag v1.0.0
git push origin v1.0.0
```

## How it works

| Part | Role |
| --- | --- |
| `Shared/AudioDevices.swift` | Core Audio wrapper: lists selectable outputs, switches output, sets volume and mute, and observes changes. |
| `Shared/AppMessage.swift` | Messages from the widget to the background app. |
| `AudioSwitcherWidget/` | The WidgetKit extension. Its buttons run App Intents. |
| `AudioSwitcher/AppDelegate.swift` | Background agent (`LSUIElement`, no window or Dock icon) that carries out the button presses and reloads the widget whenever Core Audio reports a change. |

Widgets always run sandboxed, and the sandbox won't let them change system audio settings. The widget therefore asks the background app to make the change via a distributed notification. The background app must be running for the buttons to work; it registers itself as a login item on first launch.

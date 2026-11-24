# Audio Switcher

A macOS widget for switching your sound output with a single click – no trip to System Settings required.

- **One click per device**: every output (built-in speakers, AirPods, displays, AirPlay, USB…) is a button; the active one gets a tick.
- **Mute button**: mutes or unmutes the current output. Greyed out for outputs that can't be muted (often HDMI/DisplayPort).
- **Stays in sync**: a tiny background app refreshes the widget when you plug in headphones or change the output elsewhere.
- Small, medium and large widget sizes.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later

## Installation

1. Clone the repo and open `AudioSwitcher.xcodeproj`.
2. Select the **AudioSwitcher** scheme (not *AudioSwitcherWidgetExtension*) and **My Mac**, then press **⌘R**.
3. Optionally copy the built `AudioSwitcher.app` to `/Applications` – macOS picks up widgets more reliably from there.
4. Right-click the desktop, choose **Edit Widgets…** and add **Sound Output**.

The app has no window or Dock icon. On first launch it shows a short welcome message and registers itself as a login item, so the widget stays up to date.

### Signing

The project is set to *Sign to Run Locally*, so it builds without an Apple developer account. If the widget doesn't appear in the gallery, select your own team (a free Personal Team is fine) under **Signing & Capabilities** for both targets.

## How it works

| Part | Role |
| --- | --- |
| `Shared/AudioDevices.swift` | Core Audio wrapper: lists output devices, sets the default output, mutes, and observes changes. |
| `AudioSwitcherWidget/` | The WidgetKit extension. Buttons run App Intents (`SelectOutputIntent`, `SetMuteIntent`) directly in the widget. |
| `AudioSwitcher/AppDelegate.swift` | Background agent (`LSUIElement`) that reloads the widget whenever Core Audio reports a change. |

## Tip

Prefer not to install anything? In **System Settings → Control Center**, set **Sound** to **Always Show in Menu Bar** – clicking the speaker icon then lists every output too.

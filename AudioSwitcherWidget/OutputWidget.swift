import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct OutputEntry: TimelineEntry {
    struct Row: Identifiable {
        let id: String
        let name: String
        let symbol: String
        let isSelected: Bool
    }

    let date: Date
    let isMuted: Bool
    let canMute: Bool
    /// nil when the current output has no volume control.
    let volume: Float?
    let canSetVolume: Bool
    let rows: [Row]

    static func current() -> OutputEntry {
        let selected = AudioDevices.defaultOutputID()
        let rows = AudioDevices.outputDevices().map {
            Row(id: $0.uid, name: $0.name, symbol: $0.symbol, isSelected: $0.id == selected)
        }
        guard !rows.isEmpty else { return sample }
        return OutputEntry(
            date: .now,
            isMuted: AudioDevices.isMuted,
            canMute: AudioDevices.canMute,
            volume: AudioDevices.volume,
            canSetVolume: AudioDevices.canSetVolume,
            rows: rows
        )
    }

    static let sample = OutputEntry(date: .now, isMuted: false, canMute: true, volume: 0.5, canSetVolume: true, rows: [
        Row(id: "a", name: "MacBook Pro Speakers", symbol: "speaker.wave.2", isSelected: true),
        Row(id: "b", name: "AirPods Pro", symbol: "headphones", isSelected: false),
        Row(id: "c", name: "Studio Display", symbol: "display", isSelected: false),
    ])
}

struct OutputProvider: TimelineProvider {
    func placeholder(in context: Context) -> OutputEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (OutputEntry) -> Void) {
        completion(.current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OutputEntry>) -> Void) {
        // The host app pushes reloads on device changes; this is only a safety net.
        completion(Timeline(entries: [.current()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

// MARK: - Views

struct OutputWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OutputEntry

    /// How many device rows physically fit: small and medium widgets are only ~130pt tall
    /// inside their margins. Medium uses two columns.
    private var rowsPerColumn: Int { family == .systemLarge ? 8 : 3 }
    private var columnCount: Int { family == .systemMedium ? 2 : 1 }

    /// Rows that fit, always keeping the active device visible.
    private var visibleRows: [OutputEntry.Row] {
        let capacity = rowsPerColumn * columnCount
        guard entry.rows.count > capacity else { return entry.rows }
        var rows = Array(entry.rows.prefix(capacity))
        if !rows.contains(where: \.isSelected), let selected = entry.rows.first(where: \.isSelected) {
            rows[capacity - 1] = selected
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VolumeControls(entry: entry, showsPercentage: family != .systemSmall)

            let rows = visibleRows
            HStack(alignment: .top, spacing: 6) {
                ForEach(0..<columnCount, id: \.self) { column in
                    VStack(spacing: 4) {
                        ForEach(rows.dropFirst(column * rowsPerColumn).prefix(rowsPerColumn)) { row in
                            Button(intent: SelectOutputIntent(uid: row.id)) {
                                DeviceRow(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Mute · − · volume bar · +
private struct VolumeControls: View {
    let entry: OutputEntry
    let showsPercentage: Bool

    var body: some View {
        HStack(spacing: 4) {
            ControlButton(
                systemImage: entry.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: entry.isMuted ? "Unmute" : "Mute",
                intent: SetMuteIntent(muted: !entry.isMuted),
                isEnabled: entry.canMute,
                isHighlighted: entry.isMuted
            )
            ControlButton(
                systemImage: "minus",
                label: "Volume down",
                intent: StepVolumeIntent(up: false),
                isEnabled: entry.canSetVolume
            )
            VolumeBar(value: entry.volume ?? 0, isDimmed: entry.isMuted || entry.volume == nil)
            if showsPercentage, let volume = entry.volume {
                Text("\(Int((volume * 100).rounded()))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            ControlButton(
                systemImage: "plus",
                label: "Volume up",
                intent: StepVolumeIntent(up: true),
                isEnabled: entry.canSetVolume
            )
        }
    }
}

private struct ControlButton<Intent: AppIntent>: View {
    let systemImage: String
    let label: String
    let intent: Intent
    let isEnabled: Bool
    var isHighlighted = false

    var body: some View {
        if isEnabled {
            Button(intent: intent) { icon }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
        } else {
            // The current output has no control for this (common with HDMI/DisplayPort).
            icon.opacity(0.35)
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isHighlighted ? Color.red : Color.primary)
            .frame(width: 26, height: 22)
            .background(
                Capsule().fill(isHighlighted ? Color.red.opacity(0.22) : Color.primary.opacity(0.08))
            )
            .contentShape(Capsule())
            .widgetAccentable(isHighlighted)
    }
}

private struct VolumeBar: View {
    let value: Float
    let isDimmed: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                if value > 0 {
                    Capsule()
                        .fill(isDimmed ? Color.secondary : Color.accentColor)
                        .frame(width: max(geometry.size.height, geometry.size.width * CGFloat(value)))
                        .widgetAccentable()
                }
            }
        }
        .frame(height: 6)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

private struct DeviceRow: View {
    let row: OutputEntry.Row

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: row.symbol)
                .frame(width: 16)
            Text(row.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if row.isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(row.isSelected ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.06))
        )
        .contentShape(Rectangle())
        .widgetAccentable(row.isSelected)
    }
}

// MARK: - Widget

struct OutputWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OutputWidget", provider: OutputProvider()) { entry in
            OutputWidgetView(entry: entry)
        }
        .configurationDisplayName("Sound Control")
        .description("Switch output, change the volume and mute with a single click.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct AudioSwitcherWidgetBundle: WidgetBundle {
    var body: some Widget {
        OutputWidget()
    }
}

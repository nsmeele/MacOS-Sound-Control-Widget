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
    let rows: [Row]

    static func current() -> OutputEntry {
        let selected = AudioDevices.defaultOutputID()
        let rows = AudioDevices.outputDevices().map {
            Row(id: $0.uid, name: $0.name, symbol: $0.symbol, isSelected: $0.id == selected)
        }
        guard !rows.isEmpty else { return sample }
        return OutputEntry(date: .now, isMuted: AudioDevices.isMuted, canMute: AudioDevices.canMute, rows: rows)
    }

    static let sample = OutputEntry(date: .now, isMuted: false, canMute: true, rows: [
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

    private var rowsPerColumn: Int { family == .systemLarge ? 8 : 3 }
    private var columnCount: Int { family == .systemSmall ? 1 : 2 }
    private var columnsUsed: Int { family == .systemLarge ? 1 : columnCount }

    /// Rows that fit, always keeping the active device visible.
    private var visibleRows: [OutputEntry.Row] {
        let capacity = rowsPerColumn * columnsUsed
        guard entry.rows.count > capacity else { return entry.rows }
        var rows = Array(entry.rows.prefix(capacity))
        if !rows.contains(where: \.isSelected), let selected = entry.rows.first(where: \.isSelected) {
            rows[capacity - 1] = selected
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Sound Output")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                MuteButton(isMuted: entry.isMuted, canMute: entry.canMute)
            }

            let rows = visibleRows
            HStack(alignment: .top, spacing: 6) {
                ForEach(0..<columnsUsed, id: \.self) { column in
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

private struct MuteButton: View {
    let isMuted: Bool
    let canMute: Bool

    var body: some View {
        if canMute {
            Button(intent: SetMuteIntent(muted: !isMuted)) { icon }
                .buttonStyle(.plain)
                .accessibilityLabel(isMuted ? "Unmute" : "Mute")
        } else {
            // This output has no mute control (common with HDMI/DisplayPort).
            icon.opacity(0.35)
        }
    }

    private var icon: some View {
        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isMuted ? Color.red : Color.primary)
            .frame(width: 30, height: 20)
            .background(
                Capsule().fill(isMuted ? Color.red.opacity(0.22) : Color.primary.opacity(0.08))
            )
            .contentShape(Capsule())
            .widgetAccentable(isMuted)
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
        .configurationDisplayName("Sound Output")
        .description("Choose where your sound plays with a single click.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct AudioSwitcherWidgetBundle: WidgetBundle {
    var body: some Widget {
        OutputWidget()
    }
}

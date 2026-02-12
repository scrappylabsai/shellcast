import SwiftUI

struct HistoryRow: View {
    let item: AudioItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.voice)
                        .font(ShellCastTheme.headlineFont)
                        .foregroundStyle(ShellCastTheme.accent)
                    if item.isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(ShellCastTheme.accent2)
                            .font(.caption)
                    }
                }
                if !item.text.isEmpty {
                    Text(item.text)
                        .font(.subheadline)
                        .foregroundStyle(ShellCastTheme.text)
                        .lineLimit(2)
                }
                Text(item.receivedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(ShellCastTheme.textMuted)
            }
            Spacer()
            Image(systemName: "play.circle")
                .foregroundStyle(ShellCastTheme.borderInteractive)
                .font(.title3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.voice): \(item.text)")
        .accessibilityHint("Tap to replay")
    }
}

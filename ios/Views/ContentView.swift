import SwiftUI

struct ContentView: View {
    @Bindable var client: ShellCastClient
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status bar
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(statusText)
                        .font(ShellCastTheme.captionFont)
                        .foregroundStyle(ShellCastTheme.textMuted)
                    Spacer()
                    if client.isPlaying {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(ShellCastTheme.accent)
                            .symbolEffect(.variableColor)
                    }
                    Button {
                        showDebug.toggle()
                    } label: {
                        Image(systemName: "ladybug")
                            .foregroundStyle(showDebug ? ShellCastTheme.accent : ShellCastTheme.textMuted)
                    }
                }
                .padding(ShellCastTheme.paddingMedium)
                .background(ShellCastTheme.surface)

                if showDebug {
                    // Debug log panel
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(client.debugLog.enumerated()), id: \.offset) { idx, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(ShellCastTheme.textMuted)
                                        .id(idx)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 200)
                        .background(Color.black)
                        .onChange(of: client.debugLog.count) {
                            if let last = client.debugLog.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }

                    // Copy + share button
                    HStack {
                        Button("Copy Log") {
                            UIPasteboard.general.string = client.debugLog.joined(separator: "\n")
                        }
                        .font(ShellCastTheme.captionFont)
                        .foregroundStyle(ShellCastTheme.accent)
                        Spacer()
                        Text("\(client.debugLog.count) entries")
                            .font(ShellCastTheme.captionFont)
                            .foregroundStyle(ShellCastTheme.textMuted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black)
                }

                // Main content
                if client.history.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundStyle(ShellCastTheme.textMuted)
                        Text("Waiting for audio...")
                            .font(ShellCastTheme.bodyFont)
                            .foregroundStyle(ShellCastTheme.textMuted)
                        Text("Use speak in Claude Code")
                            .font(ShellCastTheme.captionFont)
                            .foregroundStyle(ShellCastTheme.textMuted)
                    }
                    Spacer()
                } else {
                    List(client.history) { item in
                        HistoryRow(item: item)
                            .onTapGesture {
                                client.replay(item: item)
                            }
                            .listRowBackground(ShellCastTheme.surface)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(ShellCastTheme.background)
            .navigationTitle("ShellCast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ShellCastTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear { client.connect() }
    }

    private var statusColor: Color {
        switch client.connectionState {
        case .connected: ShellCastTheme.success
        case .connecting, .reconnecting: ShellCastTheme.accent
        case .disconnected: ShellCastTheme.error
        }
    }

    private var statusText: String {
        switch client.connectionState {
        case .connected: "Connected to Moya"
        case .connecting: "Connecting..."
        case .reconnecting(let n): "Reconnecting (\(n))..."
        case .disconnected: "Disconnected"
        }
    }
}

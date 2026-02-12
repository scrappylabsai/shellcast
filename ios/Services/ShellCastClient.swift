import Foundation
import AVFoundation

/// WebSocket client that connects to a ShellCast relay server.
/// Receives audio pushes and plays them, including in the background.
@MainActor
@Observable
final class ShellCastClient: NSObject, @preconcurrency URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectDelay: TimeInterval = 30
    private var pendingMeta: [String: Any]?

    // Audio playback
    private var player: AVAudioPlayer?
    private var audioQueue: [AudioItem] = []

    // Observable state
    var connectionState: ConnectionState = .disconnected
    var history: [AudioItem] = []
    var isPlaying = false
    var debugLog: [String] = []

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(ts)] \(msg)"
        print(entry)
        debugLog.append(entry)
        if debugLog.count > 100 { debugLog.removeFirst() }
    }

    // Relay URL — configurable via Settings, defaults to localhost
    var relayURL: String {
        UserDefaults.standard.string(forKey: "shellcast_relay_url") ?? "ws://localhost:9876/ws"
    }

    func setRelayURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "shellcast_relay_url")
    }

    enum ConnectionState: Equatable, Sendable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    // MARK: - Connection

    func connect() {
        guard let url = URL(string: relayURL) else {
            log("ERROR: Invalid URL: \(relayURL)")
            return
        }
        log("Connecting to \(relayURL)")
        connectionState = .connecting
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.maximumMessageSize = 50 * 1024 * 1024 // 50MB — support full songs
        webSocketTask?.resume()
        receiveMessage()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        connectionState = .disconnected
        reconnectAttempts = 0
    }

    private func reconnect() {
        reconnectTask?.cancel()
        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)

        let delay = min(pow(2.0, Double(reconnectAttempts)), maxReconnectDelay)
        log("Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts))")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await self.connect()
        }
    }

    // MARK: - Receive Loop

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.log("WS receive error: \(error.localizedDescription)")
                    self.connectionState = .disconnected
                    self.reconnect()
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleText(text)
                    case .data(let data):
                        self.handleBinary(data)
                    @unknown default:
                        break
                    }
                    self.receiveMessage()
                }
            }
        }
    }

    // MARK: - Frame Handling

    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "hello":
            connectionState = .connected
            reconnectAttempts = 0
            log("Connected to relay")

        case "meta":
            pendingMeta = json

        case "ping":
            let pong = "{\"type\":\"pong\"}"
            webSocketTask?.send(.string(pong)) { _ in }

        default:
            break
        }
    }

    private func handleBinary(_ data: Data) {
        let meta = pendingMeta
        pendingMeta = nil

        let item = AudioItem(
            id: meta?["id"] as? String ?? UUID().uuidString,
            voice: meta?["voice"] as? String ?? "unknown",
            text: meta?["text"] as? String ?? "",
            audioData: data,
            receivedAt: Date()
        )

        history.insert(item, at: 0)
        if history.count > 50 { history.removeLast() }

        audioQueue.append(item)
        if !isPlaying { playNext() }
    }

    // MARK: - Audio Playback

    private func playNext() {
        guard !audioQueue.isEmpty else {
            isPlaying = false
            return
        }
        let item = audioQueue.removeFirst()
        do {
            player = try AVAudioPlayer(data: item.audioData)
            player?.delegate = self
            player?.volume = 1.0
            player?.play()
            isPlaying = true

            if let idx = history.firstIndex(where: { $0.id == item.id }) {
                history[idx].isPlaying = true
            }
        } catch {
            log("Play error: \(error.localizedDescription)")
            playNext()
        }
    }

    /// Replay a history item.
    func replay(item: AudioItem) {
        audioQueue.insert(item, at: 0)
        if !isPlaying { playNext() }
    }

    // MARK: - URLSessionWebSocketDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            self.log("WebSocket opened")
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor in
            self.log("WebSocket closed: \(closeCode) reason=\(reason.map { String(data: $0, encoding: .utf8) ?? "binary" } ?? "none")")
            self.connectionState = .disconnected
            self.reconnect()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension ShellCastClient: @preconcurrency AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if let idx = self.history.firstIndex(where: { $0.isPlaying }) {
                self.history[idx].isPlaying = false
            }
            self.playNext()
        }
    }
}

<p align="center">
  <h1 align="center">ShellCast</h1>
  <p align="center"><strong>Push audio from any headless server to your phone. One HTTP POST, instant playback.</strong></p>
</p>

<p align="center">
  <a href="https://github.com/scrappylabsai/shellcast/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/relay-Node.js-green" alt="Node.js">
  <img src="https://img.shields.io/badge/client-iOS%20(Swift)-blue" alt="iOS">
  <img src="https://img.shields.io/badge/protocol-WebSocket-purple" alt="WebSocket">
  <img src="https://img.shields.io/badge/lines-111-brightgreen" alt="111 lines">
</p>

---

You're SSH'd into a server running TTS, generating music, or processing audio. You can't hear it -- it plays on the remote machine, or worse, there's no audio device at all.

ShellCast fixes that. `curl -X POST` your audio bytes to the relay, and they play on your phone instantly. No accounts, no cloud, no config files. One relay, one WebSocket, done.

```
 Any Server                     ShellCast Relay               Your Phone
 ┌────────────┐    POST /push   ┌──────────────┐   WebSocket  ┌──────────┐
 │ TTS engine │───(audio bytes)─│  111 lines   │──broadcast──│ iOS app  │
 │ Music gen  │                 │  of Node.js  │              │ plays it │
 │ AI pipeline│                 └──────────────┘              └──────────┘
 └────────────┘
```

## Why ShellCast?

- **Zero config** -- `npm install && node server.js`. That's the setup.
- **Any audio format** -- MP3, WAV, AAC, FLAC, OGG. Whatever the server generates, the phone plays.
- **Files up to 50MB** -- Full songs, not just notification clips.
- **No cloud** -- Runs on your LAN or Tailscale mesh. Audio never leaves your network.
- **Metadata passthrough** -- Voice name, text content, and IDs travel with the audio as HTTP headers.

## Quick Start

### 1. Start the Relay

```bash
git clone https://github.com/scrappylabsai/shellcast.git
cd shellcast/relay
npm install
node server.js
# ShellCast relay listening on :9876
```

### 2. Build the iOS App

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode 16+.

```bash
cd ios
xcodegen generate
open ShellCast.xcodeproj
# Build and run on your device
```

Set your relay URL in the app settings. Default: `ws://localhost:9876/ws`

### 3. Push Audio

```bash
# Push any audio file
curl -X POST http://localhost:9876/push \
  -H "X-Voice: narrator" \
  -H "X-Text: Hello from the server" \
  --data-binary @speech.mp3

# Response: {"ok": true, "clients": 1, "bytes": 51672}
```

From a script, TTS pipeline, or MCP tool:
```bash
# Generate TTS and push in one line
your-tts-engine "Hello world" -o /tmp/out.wav && \
  curl -X POST http://localhost:9876/push --data-binary @/tmp/out.wav
```

## Relay API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/push` | `POST` | Push audio to all connected clients. Body = raw audio bytes. |
| `/status` | `GET` | Returns `{"clients": N, "uptime": seconds}` |
| `/ws` | WebSocket | Client connection endpoint |

### Push Headers (all optional)

| Header | Description |
|--------|-------------|
| `X-Voice` | Voice/speaker name (forwarded to clients as metadata) |
| `X-Text` | Text content that was spoken (for display) |
| `X-Id` | Unique ID for this audio clip |

### WebSocket Messages

Clients receive two messages per push:
1. **JSON metadata**: `{"type": "meta", "voice": "narrator", "text": "Hello", "id": "..."}`
2. **Binary audio data**: Raw bytes, same format as the POST body

The relay also sends periodic pings (`{"type": "ping", "ts": ...}`) every 15 seconds for keepalive.

## iOS App Features

- **Auto-reconnect** with exponential backoff -- survives network changes, server restarts
- **Audio queue** with sequential playback -- pushes stack up, play in order
- **Background audio** -- keeps playing when the app is backgrounded
- **Tap-to-replay** history of last 50 items
- **Debug panel** -- tap the bug icon for connection state and message log
- **Configurable relay URL** -- set once, persists across launches
- **Any format** -- if AVAudioPlayer can decode it, ShellCast plays it

## Run as a Service

### Linux (systemd)

```bash
cp relay/shellcast-relay.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now shellcast-relay
```

### Custom Port

```bash
SHELLCAST_PORT=8080 node server.js
```

## Architecture

The relay is **111 lines of Node.js**. One file, one dependency (`ws`), no framework.

```
relay/
├── server.js       # HTTP server + WebSocket relay (111 lines)
├── package.json    # One dependency: ws
└── shellcast-relay.service  # systemd unit file

ios/
├── ShellCastApp.swift    # App entry point
├── Services/             # WebSocket client, audio player
├── Views/                # SwiftUI views
├── Models/               # Data models
└── project.yml           # XcodeGen spec
```

### Design Philosophy

- **No auth** -- designed for private networks (LAN, Tailscale, VPN). If you need auth, put nginx in front.
- **No persistence** -- audio is forwarded and forgotten. The relay holds zero state between pushes.
- **No transcoding** -- whatever bytes go in, those bytes go out. The client handles decoding.
- **No framework** -- raw `http.createServer` and `ws`. Nothing to configure, nothing to break.

## Use Cases

| Use Case | How |
|----------|-----|
| **TTS playback** | AI agent generates speech, pushes to your phone so you hear it anywhere |
| **Music generation** | Pipe output from AI music models for instant preview |
| **Build notifications** | Push a chime when your CI build finishes |
| **Audio monitoring** | Stream processed audio clips for review |
| **Podcast editing** | Push segments to your phone for on-the-go review |
| **Fleet alerts** | Server generates voice alerts, you hear them on your phone |

## Network Configuration

| Network | Relay URL |
|---------|-----------|
| Same machine | `ws://localhost:9876/ws` |
| LAN | `ws://10.0.0.5:9876/ws` |
| Tailscale | `ws://your-node.tailnet.ts.net:9876/ws` |

**Note:** ShellCast uses `ws://` (unencrypted WebSocket), not `wss://`. This is intentional -- it's designed for private networks. For Tailscale with MagicDNS hostnames on iOS, add an ATS exception domain in `project.yml`.

## BrainJack Ecosystem

| Component | Description |
|-----------|-------------|
| **[ShellCast](https://github.com/scrappylabsai/shellcast)** | This repo. Audio relay. |
| **[BrainJack Agent](https://github.com/scrappylabsai/brainjack-agent)** | WebSocket daemon for keystroke injection on Linux/macOS. |
| **[BrainJack HID](https://github.com/scrappylabsai/brainjack-hid)** | ESP32-S3 USB dongle. WiFi to USB HID. |
| **[ShellDrop FAP](https://github.com/scrappylabsai/shelldrop-flipper)** | Flipper Zero voice-to-keystroke app. |
| **[ShellDrop Bridge](https://github.com/scrappylabsai/shelldrop-bridge)** | ESP32-S2 WiFi bridge for Flipper Zero. |

## Contributing

PRs welcome. The relay should stay under 200 lines. The iOS app should stay simple. If a feature requires a database, it doesn't belong here.

1. Fork the repo
2. Make your changes
3. Test with a real iOS device (simulators can't do background audio)
4. Submit a PR

## License

[Apache License 2.0](LICENSE)

---

Built by [ScrappyLabs](https://scrappylabs.ai) | [brainjack.ai](https://brainjack.ai)

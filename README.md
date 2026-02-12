# ShellCast

Push audio from any headless server to your iPhone over WebSocket.

**The problem:** You're SSH'd into a server generating TTS, music, or other audio — but you can't hear it because it plays on the remote machine.

**ShellCast fixes that.** A lightweight relay receives audio via HTTP POST and broadcasts it to connected iOS clients over WebSocket. Works over Tailscale, LAN, or any network.

```
Server (TTS, music gen, etc.)
    ↓ POST /push (audio bytes)
ShellCast Relay (Node.js, 111 lines)
    ↓ WebSocket broadcast
iPhone App → plays audio
```

## Quick Start

### 1. Start the relay

```bash
cd relay
npm install
node server.js
# ShellCast relay listening on :9876
```

### 2. Build the iOS app

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode 16+.

```bash
cd ios
xcodegen generate
open ShellCast.xcodeproj
```

Set your relay URL in the app (defaults to `ws://localhost:9876/ws`).

### 3. Push audio

```bash
# Push any audio file (MP3, WAV, AAC, FLAC...)
curl -X POST http://localhost:9876/push \
  -H "X-Voice: narrator" \
  -H "X-Text: Hello from the server" \
  --data-binary @audio.mp3

# Response:
# {"ok": true, "clients": 1, "bytes": 51672}
```

## Relay API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/push` | POST | Push audio to all connected clients. Body = raw audio bytes. Optional headers: `X-Voice`, `X-Text`, `X-Id` for metadata. |
| `/status` | GET | Returns `{"clients": N, "uptime": seconds}` |
| `/ws` | WS | Client connection endpoint |

## iOS App Features

- Auto-reconnect with exponential backoff
- Audio queue with sequential playback
- Background audio mode (keeps playing when app is backgrounded)
- Tap-to-replay history (last 50 items)
- Debug panel (tap the bug icon)
- Supports files up to 50MB (full songs, not just clips)
- Configurable relay URL

## Run as a Service

```bash
# Copy the systemd unit (Linux, user service)
cp relay/shellcast-relay.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now shellcast-relay
```

## Use Cases

- **TTS playback** — Claude Code, MCP tools, or any TTS engine pushes speech to your phone
- **AI music generation** — Pipe output from ACE-Step, MiniMax, or any music gen model
- **Podcast/audio monitoring** — Push processed audio clips for review
- **Any headless audio** — If a server generates audio and you want to hear it, ShellCast relays it

## Architecture

The relay is intentionally minimal — 111 lines of Node.js, no framework, no auth, no persistence. It holds WebSocket connections and forwards audio. The iOS app is ~200 lines of Swift using `URLSessionWebSocketTask` and `AVAudioPlayer`.

No accounts, no cloud, no telemetry. Your audio stays on your network.

## Network Notes

- Works over LAN (`ws://192.168.x.x:9876/ws`)
- Works over Tailscale (`ws://your-node.tailnet.ts.net:9876/ws`)
- For Tailscale with MagicDNS hostnames, add an ATS exception domain in `project.yml` (see iOS ATS docs)
- Plain `ws://` (not `wss://`) — designed for private networks, not the public internet

## License

MIT

---

Built by [ScrappyLabs](https://scrappylabs.ai)

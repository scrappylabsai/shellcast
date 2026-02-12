#!/usr/bin/env node
/**
 * ShellCast Relay — WebSocket audio broadcast relay.
 *
 * MCP pushes audio via HTTP POST /push, relay broadcasts to
 * connected iOS clients via WebSocket on /ws.
 *
 * Runs on Moya, reachable over Tailscale only.
 */
import { createServer } from 'http';
import { WebSocketServer } from 'ws';

const PORT = process.env.SHELLCAST_PORT || 9876;
const clients = new Set();

// WebSocket server (noServer mode — we handle upgrade manually)
const wss = new WebSocketServer({ noServer: true });

wss.on('connection', (ws, req) => {
  const addr = req.socket.remoteAddress;
  console.log(`[ws] Client connected from ${addr} (${clients.size + 1} total)`);
  clients.add(ws);

  ws.send(JSON.stringify({ type: 'hello', version: 1, relay: 'moya' }));

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'pong') return; // keepalive response
    } catch {
      // ignore non-JSON
    }
  });

  ws.on('close', () => {
    clients.delete(ws);
    console.log(`[ws] Client disconnected (${clients.size} remaining)`);
  });

  ws.on('error', (err) => {
    console.error(`[ws] Client error: ${err.message}`);
    clients.delete(ws);
  });
});

// Heartbeat ping every 15s
setInterval(() => {
  const ping = JSON.stringify({ type: 'ping', ts: Date.now() });
  for (const ws of clients) {
    if (ws.readyState === 1) ws.send(ping);
  }
}, 15000);

// HTTP server handles POST /push, GET /status, and WS upgrade
const httpServer = createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/push') {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const audioData = Buffer.concat(chunks);
      const meta = {
        type: 'meta',
        voice: req.headers['x-voice'] || 'unknown',
        text: req.headers['x-text'] || '',
        id: req.headers['x-id'] || Date.now().toString(),
      };

      const metaJson = JSON.stringify(meta);
      let sent = 0;
      for (const ws of clients) {
        if (ws.readyState === 1) {
          ws.send(metaJson);
          ws.send(audioData);
          sent++;
        }
      }

      console.log(`[push] ${(audioData.length / 1024).toFixed(1)}KB → ${sent} client(s) | voice=${meta.voice}`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, clients: sent, bytes: audioData.length }));
    });
    return;
  }

  if (req.method === 'GET' && req.url === '/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      clients: clients.size,
      uptime: Math.floor(process.uptime()),
    }));
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

httpServer.on('upgrade', (req, socket, head) => {
  if (req.url === '/ws') {
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  } else {
    socket.destroy();
  }
});

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`ShellCast relay listening on :${PORT}`);
});

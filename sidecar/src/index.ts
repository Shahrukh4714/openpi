import { createServer } from 'node:http';
import { WebSocketServer, WebSocket } from 'ws';
import { RpcServer } from './rpc.js';

const DEFAULT_PORT = 8765;
const HOST = '127.0.0.1';

const port = Number(process.env.OPENPI_PORT ?? DEFAULT_PORT);

const rpc = new RpcServer();

rpc.handle('ping', () => ({
  pong: true,
  version: '0.1.0',
  harness: {
    piAi: 'registered-placeholder',
    piAgentCore: 'registered-placeholder'
  },
  pid: process.pid,
  uptimeSec: Math.round(process.uptime())
}));

const server = createServer((_req, res) => {
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ name: 'openpi-sidecar', status: 'ok' }));
});

const wss = new WebSocketServer({ server });

wss.on('connection', (socket: WebSocket) => {
  socket.on('message', async (data) => {
    const reply = await rpc.process(data.toString());
    if (reply && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify(reply));
    }
  });
});

server.listen(port, HOST, () => {
  const line = JSON.stringify({
    event: 'ready',
    transport: 'ws',
    host: HOST,
    port,
    pid: process.pid
  });
  process.stdout.write(`${line}\n`);
});

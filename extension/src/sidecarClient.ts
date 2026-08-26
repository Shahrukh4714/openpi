import * as vscode from 'vscode';
import { WebSocket } from 'ws';

type StatusListener = (connected: boolean) => void;

export class SidecarClient implements vscode.Disposable {
  private socket: WebSocket | undefined;
  private listeners: StatusListener[] = [];
  private nextId = 1;
  private pending = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();
  private disposed = false;

  constructor(
    private readonly context: vscode.ExtensionContext,
    private readonly log: vscode.LogOutputChannel
  ) {}

  onStatusChange(listener: StatusListener): void {
    this.listeners.push(listener);
  }

  get connected(): boolean {
    return this.socket?.readyState === WebSocket.OPEN;
  }

  async connect(): Promise<void> {
    const port = vscode.workspace.getConfiguration('openpi').get<number>('sidecar.port', 8765);
    const url = `ws://127.0.0.1:${port}`;
    try {
      this.socket = new WebSocket(url);
      this.socket.on('open', () => {
        this.log.info(`sidecar connected at ${url}`);
        this.emit(true);
      });
      this.socket.on('message', (data) => this.handleMessage(String(data)));
      this.socket.on('error', (err) => this.log.warn(`sidecar socket error: ${err.message}`));
      this.socket.on('close', () => {
        this.emit(false);
        if (!this.disposed) {
          setTimeout(() => void this.trySpawnAndReconnect(), 2000);
        }
      });
    } catch (err) {
      this.log.warn(`sidecar connect failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  async request<T>(method: string, params?: unknown): Promise<T> {
    if (!this.connected || !this.socket) throw new Error('sidecar not connected');
    const id = this.nextId++;
    const payload = JSON.stringify({ jsonrpc: '2.0', id, method, params });
    return new Promise<T>((resolve, reject) => {
      this.pending.set(id, { resolve: resolve as (v: unknown) => void, reject });
      this.socket!.send(payload);
    });
  }

  private handleMessage(raw: string): void {
    try {
      const msg = JSON.parse(raw) as { id?: number; result?: unknown; error?: { message: string } };
      if (typeof msg.id === 'number' && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id)!;
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(msg.error.message));
        else resolve(msg.result);
      }
    } catch {
      this.log.warn('unparseable sidecar message dropped');
    }
  }

  private emit(connected: boolean): void {
    for (const l of this.listeners) l(connected);
  }

  private async trySpawnAndReconnect(): Promise<void> {
    const cfg = vscode.workspace.getConfiguration('openpi').get<string>('sidecar.executablePath', '');
    if (!cfg) {
      this.log.info('no sidecar executable configured; retrying connection only');
      return void this.connect();
    }
    this.log.info('spawning sidecar process');
    const proc = require('child_process').spawn(cfg, [], {
      env: { ...process.env, OPENPI_PORT: String(vscode.workspace.getConfiguration('openpi').get('sidecar.port', 8765)) },
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true
    }) as import('child_process').ChildProcess;
    this.context.subscriptions.push({ dispose: () => proc.kill() });
    proc.stdout?.on('data', (d: Buffer) => this.log.info(`[sidecar] ${String(d).trim()}`));
    proc.stderr?.on('data', (d: Buffer) => this.log.warn(`[sidecar] ${String(d).trim()}`));
    proc.on('exit', (code) => this.log.warn(`sidecar exited with code ${code}`));
    await new Promise((r) => setTimeout(r, 1500));
    await this.connect();
  }

  dispose(): void {
    this.disposed = true;
    this.socket?.close();
  }
}

import type { IncomingMessage, ServerResponse } from 'http';

export interface RpcRequest {
  jsonrpc: '2.0';
  id: number | string | null;
  method: string;
  params?: unknown;
}

export interface RpcResponse {
  jsonrpc: '2.0';
  id: number | string | null;
  result?: unknown;
  error?: { code: number; message: string; data?: unknown };
}

type Handler = (params: unknown) => Promise<unknown> | unknown;

export class RpcServer {
  private handlers = new Map<string, Handler>();

  handle(method: string, handler: Handler): void {
    this.handlers.set(method, handler);
  }

  hasHandlers(): boolean {
    return this.handlers.size > 0;
  }

  async process(raw: string): Promise<RpcResponse | null> {
    let req: RpcRequest;
    try {
      req = JSON.parse(raw);
    } catch {
      return this.error(null, -32700, 'parse error');
    }
    if (!req || req.jsonrpc !== '2.0' || typeof req.method !== 'string') {
      return this.error(req?.id ?? null, -32600, 'invalid request');
    }
    const handler = this.handlers.get(req.method);
    if (!handler) {
      return this.error(req.id, -32601, `method not found: ${req.method}`);
    }
    try {
      const result = await handler(req.params);
      if (req.id === null || req.id === undefined) return null;
      return { jsonrpc: '2.0', id: req.id, result };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return this.error(req.id, -32000, message);
    }
  }

  private error(id: number | string | null, code: number, message: string): RpcResponse {
    return { jsonrpc: '2.0', id, error: { code, message } };
  }
}

export function writeStdoutLine(obj: unknown): void {
  process.stdout.write(`${JSON.stringify(obj)}\n`);
}

export type { IncomingMessage, ServerResponse };

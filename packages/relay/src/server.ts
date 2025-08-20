// Yjs WebSocket服务器 - 处理实时协作
import WebSocket, { WebSocketServer } from 'ws';
import * as Y from 'yjs';
import * as syncProtocol from 'y-protocols/sync.js';
import * as awarenessProtocol from 'y-protocols/awareness.js';
import { encoding, decoding } from 'lib0';

// 文档存储
const docs: Map<string, WSSharedDoc> = new Map();

// WebSocket共享文档类
class WSSharedDoc extends Y.Doc {
  public conns: Map<any, Set<number>> = new Map();
  public awareness: awarenessProtocol.Awareness;

  constructor(public name: string) {
    super();
    this.awareness = new awarenessProtocol.Awareness(this);
    this.awareness.setLocalState(null);

    // 监听awareness变化
    this.awareness.on('update', this.awarenessUpdateHandler.bind(this));
  }

  private awarenessUpdateHandler = ({ added, updated, removed }: any, conn: any) => {
    const changedClients = added.concat(updated, removed);
    this.conns.forEach((_, c) => {
      if (c !== conn) {
        this.sendAwarenessMessage(c, changedClients);
      }
    });
  };

  private sendAwarenessMessage(conn: any, clients: number[]) {
    const encoder = encoding.createEncoder();
    encoding.writeVarUint(encoder, 1); // awareness message type
    const awarenessUpdate = awarenessProtocol.encodeAwarenessUpdate(this.awareness, clients);
    encoding.writeVarUint8Array(encoder, awarenessUpdate);
    this.send(conn, encoding.toUint8Array(encoder));
  }

  public send(conn: any, m: Uint8Array) {
    if (conn.readyState !== 1) return;
    try {
      conn.send(m, (err: any) => {
        err != null && this.closeConn(conn);
      });
    } catch (e) {
      this.closeConn(conn);
    }
  }

  public closeConn(conn: any) {
    if (this.conns.has(conn)) {
      const controlledIds = this.conns.get(conn)!;
      this.conns.delete(conn);
      awarenessProtocol.removeAwarenessStates(this.awareness, Array.from(controlledIds), null);
      if (this.conns.size === 0 && docs.has(this.name)) {
        docs.delete(this.name);
      }
    }
    conn.close();
  }
}

// 获取或创建文档
const getYDoc = (docName: string): WSSharedDoc => {
  if (!docs.has(docName)) {
    const doc = new WSSharedDoc(docName);
    docs.set(docName, doc);
  }
  return docs.get(docName)!;
};

// 消息处理
const messageListener = (conn: any, doc: WSSharedDoc, message: Uint8Array) => {
  try {
    const encoder = encoding.createEncoder();
    const decoder = decoding.createDecoder(message);
    const messageType = decoding.readVarUint(decoder);

    switch (messageType) {
      case 0: // sync message type
        encoding.writeVarUint(encoder, 0);
        syncProtocol.readSyncMessage(decoder, encoder, doc, conn);
          if (encoding.length(encoder) > 1) {
            doc.send(conn, encoding.toUint8Array(encoder));
          }
        break;
      case 1: // awareness message type
        awarenessProtocol.applyAwarenessUpdate(doc.awareness, decoding.readVarUint8Array(decoder), conn);
        break;
    }
  } catch (err) {
    console.error('Error handling message:', err);
    doc.closeConn(conn);
  }
};

// 设置WebSocket连接
const setupWSConnection = (conn: any, req: any) => {
  conn.binaryType = 'arraybuffer';
  
  // 从URL获取文档名
  const docName = req.url.slice(1).split('?')[0];
  const doc = getYDoc(docName);

  doc.conns.set(conn, new Set());
  
  // 监听消息
  conn.on('message', (message: ArrayBuffer) => {
    messageListener(conn, doc, new Uint8Array(message));
  });

  // 连接关闭处理
  conn.on('close', () => {
    doc.closeConn(conn);
  });

  // 发送同步步骤1
  const encoder = encoding.createEncoder();
  encoding.writeVarUint(encoder, 0);
  syncProtocol.writeSyncStep1(encoder, doc);
  doc.send(conn, encoding.toUint8Array(encoder));
  
  // 同步步骤1：发送当前状态
  const awarenessEncoder = encoding.createEncoder();
  encoding.writeVarUint(awarenessEncoder, 1);
  const awarenessUpdate = awarenessProtocol.encodeAwarenessUpdate(doc.awareness, [doc.awareness.clientID]);
  encoding.writeVarUint8Array(awarenessEncoder, awarenessUpdate);
  doc.send(conn, encoding.toUint8Array(awarenessEncoder));
};

// 启动服务器
export const startServer = (port: number = 1234) => {
  const wss = new WebSocketServer({ port });
  
  wss.on('connection', setupWSConnection);
  
  console.log(`Yjs WebSocket server running on port ${port}`);
  
  return wss;
};

// 如果是直接运行
if (import.meta.url === `file://${process.argv[1]}`) {
  const port = process.env.PORT ? parseInt(process.env.PORT) : 1234;
  startServer(port);
}
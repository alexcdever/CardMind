export interface Block {
    id: string;
    type: 'text' | 'image' | 'code' | 'table' | 'todo';
    content: string;
    metadata?: Record<string, any>;
    createdAt: Date;
    updatedAt: Date;
    position: Position;
}
export interface Position {
    x: number;
    y: number;
    width?: number;
    height?: number;
}
export interface Document {
    id: string;
    title: string;
    blocks: Block[];
    tags: string[];
    createdAt: Date;
    updatedAt: Date;
    version: number;
}
export interface SyncStatus {
    isOnline: boolean;
    lastSyncTime?: Date;
    pendingChanges: number;
}
export interface Collaborator {
    id: string;
    name: string;
    color: string;
    cursor?: Position;
    lastActive: Date;
}
export interface AppConfig {
    theme: 'light' | 'dark' | 'auto';
    language: string;
    autoSave: boolean;
    syncInterval: number;
}
export interface DatabaseOperations {
    createDocument(doc: Omit<Document, 'id' | 'createdAt' | 'updatedAt' | 'version'>): Promise<Document>;
    updateDocument(id: string, updates: Partial<Document>): Promise<Document>;
    deleteDocument(id: string): Promise<void>;
    getDocument(id: string): Promise<Document | null>;
    getAllDocuments(): Promise<Document[]>;
    searchDocuments(query: string): Promise<Document[]>;
}
export type AppEvent = {
    type: 'document_created';
    documentId: string;
} | {
    type: 'document_updated';
    documentId: string;
} | {
    type: 'document_deleted';
    documentId: string;
} | {
    type: 'sync_started';
} | {
    type: 'sync_completed';
} | {
    type: 'collaborator_joined';
    userId: string;
} | {
    type: 'collaborator_left';
    userId: string;
};
//# sourceMappingURL=index.d.ts.map
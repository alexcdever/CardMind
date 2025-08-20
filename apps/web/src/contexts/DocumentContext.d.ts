import React from 'react';
import { Document, Block } from '@cardmind/types';
interface DocumentState {
    documents: Document[];
    currentDocument: Document | null;
    isLoading: boolean;
    error: string | null;
}
type DocumentAction = {
    type: 'SET_LOADING';
    payload: boolean;
} | {
    type: 'SET_ERROR';
    payload: string | null;
} | {
    type: 'SET_DOCUMENTS';
    payload: Document[];
} | {
    type: 'SET_CURRENT_DOCUMENT';
    payload: Document | null;
} | {
    type: 'ADD_DOCUMENT';
    payload: Document;
} | {
    type: 'UPDATE_DOCUMENT';
    payload: Document;
} | {
    type: 'DELETE_DOCUMENT';
    payload: string;
} | {
    type: 'ADD_BLOCK';
    payload: Block;
} | {
    type: 'UPDATE_BLOCK';
    payload: {
        documentId: string;
        block: Block;
    };
} | {
    type: 'DELETE_BLOCK';
    payload: {
        documentId: string;
        blockId: string;
    };
};
export declare function DocumentProvider({ children }: {
    children: React.ReactNode;
}): import("react/jsx-runtime").JSX.Element;
export declare function useDocuments(): {
    state: DocumentState;
    dispatch: React.Dispatch<DocumentAction>;
    createDocument: (title: string) => Promise<void>;
    updateDocument: (id: string, updates: Partial<Document>) => Promise<void>;
    deleteDocument: (id: string) => Promise<void>;
    loadDocuments: () => Promise<void>;
    loadDocument: (id: string) => Promise<void>;
    addBlock: (block: Omit<Block, "id" | "createdAt" | "updatedAt">) => Promise<void>;
    updateBlock: (block: Block) => Promise<void>;
    deleteBlock: (documentId: string, blockId: string) => Promise<void>;
};
export {};
//# sourceMappingURL=DocumentContext.d.ts.map
import React from 'react';
import type { Collaborator, SyncStatus } from '@cardmind/types';
interface SyncContextType {
    isOnline: boolean;
    collaborators: Collaborator[];
    syncStatus: SyncStatus;
    connectToDocument: (documentId: string) => void;
    disconnectFromDocument: (documentId: string) => void;
    setUserPresence: (user: {
        id: string;
        name: string;
        color: string;
    }, cursor?: {
        x: number;
        y: number;
    }) => void;
}
export declare function SyncProvider({ children }: {
    children: React.ReactNode;
}): import("react/jsx-runtime").JSX.Element;
export declare function useSync(): SyncContextType;
export {};
//# sourceMappingURL=SyncContext.d.ts.map
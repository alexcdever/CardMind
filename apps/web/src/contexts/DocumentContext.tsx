// 文档上下文 - 管理文档状态
import React, { createContext, useContext, useReducer, useEffect } from 'react';
import { Document, Block } from '@cardmind/types';
import { databaseService } from '@cardmind/shared';

// 状态类型
interface DocumentState {
  documents: Document[];
  currentDocument: Document | null;
  isLoading: boolean;
  error: string | null;
}

// 动作类型
type DocumentAction =
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_DOCUMENTS'; payload: Document[] }
  | { type: 'SET_CURRENT_DOCUMENT'; payload: Document | null }
  | { type: 'ADD_DOCUMENT'; payload: Document }
  | { type: 'UPDATE_DOCUMENT'; payload: Document }
  | { type: 'DELETE_DOCUMENT'; payload: string }
  | { type: 'ADD_BLOCK'; payload: Block }
  | { type: 'UPDATE_BLOCK'; payload: { documentId: string; block: Block } }
  | { type: 'DELETE_BLOCK'; payload: { documentId: string; blockId: string } };

// 初始状态
const initialState: DocumentState = {
  documents: [],
  currentDocument: null,
  isLoading: false,
  error: null
};

// Reducer函数
function documentReducer(state: DocumentState, action: DocumentAction): DocumentState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, isLoading: action.payload };
    case 'SET_ERROR':
      return { ...state, error: action.payload };
    case 'SET_DOCUMENTS':
      return { ...state, documents: action.payload };
    case 'SET_CURRENT_DOCUMENT':
      return { ...state, currentDocument: action.payload };
    case 'ADD_DOCUMENT':
      return { ...state, documents: [action.payload, ...state.documents] };
    case 'UPDATE_DOCUMENT':
      return {
        ...state,
        documents: state.documents.map(doc =>
          doc.id === action.payload.id ? action.payload : doc
        ),
        currentDocument: state.currentDocument?.id === action.payload.id
          ? action.payload
          : state.currentDocument
      };
    case 'DELETE_DOCUMENT':
      return {
        ...state,
        documents: state.documents.filter(doc => doc.id !== action.payload),
        currentDocument: state.currentDocument?.id === action.payload
          ? null
          : state.currentDocument
      };
    case 'ADD_BLOCK':
      if (!state.currentDocument) return state;
      const newBlock = action.payload;
      const updatedDocWithBlock = {
        ...state.currentDocument,
        blocks: [...state.currentDocument.blocks, newBlock],
        updatedAt: new Date()
      };
      return {
        ...state,
        currentDocument: updatedDocWithBlock,
        documents: state.documents.map(doc =>
          doc.id === updatedDocWithBlock.id ? updatedDocWithBlock : doc
        )
      };
    case 'UPDATE_BLOCK':
      if (!state.currentDocument) return state;
      const updatedBlock = action.payload.block;
      const updatedDocWithUpdatedBlock = {
        ...state.currentDocument,
        blocks: state.currentDocument.blocks.map(block =>
          block.id === updatedBlock.id ? updatedBlock : block
        ),
        updatedAt: new Date()
      };
      return {
        ...state,
        currentDocument: updatedDocWithUpdatedBlock,
        documents: state.documents.map(doc =>
          doc.id === updatedDocWithUpdatedBlock.id ? updatedDocWithUpdatedBlock : doc
        )
      };
    case 'DELETE_BLOCK':
      if (!state.currentDocument) return state;
      const updatedDocWithoutBlock = {
        ...state.currentDocument,
        blocks: state.currentDocument.blocks.filter(
          block => block.id !== action.payload.blockId
        ),
        updatedAt: new Date()
      };
      return {
        ...state,
        currentDocument: updatedDocWithoutBlock,
        documents: state.documents.map(doc =>
          doc.id === updatedDocWithoutBlock.id ? updatedDocWithoutBlock : doc
        )
      };
    default:
      return state;
  }
}

// 上下文
const DocumentContext = createContext<{
  state: DocumentState;
  dispatch: React.Dispatch<DocumentAction>;
  createDocument: (title: string) => Promise<void>;
  updateDocument: (id: string, updates: Partial<Document>) => Promise<void>;
  deleteDocument: (id: string) => Promise<void>;
  loadDocuments: () => Promise<void>;
  loadDocument: (id: string) => Promise<void>;
  addBlock: (block: Omit<Block, 'id' | 'createdAt' | 'updatedAt'>) => Promise<void>;
  updateBlock: (block: Block) => Promise<void>;
  deleteBlock: (documentId: string, blockId: string) => Promise<void>;
} | null>(null);

// 提供者组件
export function DocumentProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(documentReducer, initialState);

  // 加载所有文档
  const loadDocuments = async () => {
    try {
      dispatch({ type: 'SET_LOADING', payload: true });
      const documents = await databaseService.getAllDocuments();
      dispatch({ type: 'SET_DOCUMENTS', payload: documents });
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: (error as Error).message });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  };

  // 加载单个文档
  const loadDocument = async (id: string) => {
    try {
      dispatch({ type: 'SET_LOADING', payload: true });
      const document = await databaseService.getDocument(id);
      if (document) {
        dispatch({ type: 'SET_CURRENT_DOCUMENT', payload: document });
      }
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: (error as Error).message });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  };

  // 创建文档
  const createDocument = async (title: string) => {
    try {
      const document = await databaseService.createDocument({
        title,
        blocks: [],
        tags: []
      });
      dispatch({ type: 'ADD_DOCUMENT', payload: document });
      dispatch({ type: 'SET_CURRENT_DOCUMENT', payload: document });
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: (error as Error).message });
    }
  };

  // 更新文档
  const updateDocument = async (id: string, updates: Partial<Document>) => {
    try {
      const document = await databaseService.updateDocument(id, updates);
      dispatch({ type: 'UPDATE_DOCUMENT', payload: document });
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: (error as Error).message });
    }
  };

  // 删除文档
  const deleteDocument = async (id: string) => {
    try {
      await databaseService.deleteDocument(id);
      dispatch({ type: 'DELETE_DOCUMENT', payload: id });
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: (error as Error).message });
    }
  };

  // 添加块
  const addBlock = async (block: Omit<Block, 'id' | 'createdAt' | 'updatedAt'>) => {
    if (!state.currentDocument) return;

    const newBlock: Block = {
      ...block,
      id: crypto.randomUUID(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const updatedDocument = {
      ...state.currentDocument,
      blocks: [...state.currentDocument.blocks, newBlock]
    };

    await updateDocument(state.currentDocument.id, updatedDocument);
    dispatch({ type: 'ADD_BLOCK', payload: newBlock });
  };

  // 更新块
  const updateBlock = async (block: Block) => {
    if (!state.currentDocument) return;

    const updatedBlock = { ...block, updatedAt: new Date() };
    
    const updatedDocument = {
      ...state.currentDocument,
      blocks: state.currentDocument.blocks.map(b =>
        b.id === updatedBlock.id ? updatedBlock : b
      )
    };

    await updateDocument(state.currentDocument.id, updatedDocument);
    dispatch({ type: 'UPDATE_BLOCK', payload: { documentId: state.currentDocument.id, block: updatedBlock } });
  };

  // 删除块
  const deleteBlock = async (documentId: string, blockId: string) => {
    if (!state.currentDocument) return;

    const updatedDocument = {
      ...state.currentDocument,
      blocks: state.currentDocument.blocks.filter(b => b.id !== blockId)
    };

    await updateDocument(documentId, updatedDocument);
    dispatch({ type: 'DELETE_BLOCK', payload: { documentId, blockId } });
  };

  // 初始化加载
  useEffect(() => {
    loadDocuments();
  }, []);

  const value = {
    state,
    dispatch,
    createDocument,
    updateDocument,
    deleteDocument,
    loadDocuments,
    loadDocument,
    addBlock,
    updateBlock,
    deleteBlock
  };

  return (
    <DocumentContext.Provider value={value}>
      {children}
    </DocumentContext.Provider>
  );
}

// Hook
export function useDocuments() {
  const context = useContext(DocumentContext);
  if (!context) {
    throw new Error('useDocuments must be used within a DocumentProvider');
  }
  return context;
}
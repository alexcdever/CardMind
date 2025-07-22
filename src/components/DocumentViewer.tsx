import React, { useEffect } from 'react';
import { useBlockManager } from '../stores/blockManager';
import { Layout } from 'antd';
import { BlockType } from '../types/block';
const { Content, Header } = Layout;

interface Props {
  blockId: string;
  children?: React.ReactNode;
}

export const DocumentViewer: React.FC<Props> = ({ blockId, children }) => {
  const { openBlockDoc, closeBlockDoc, openBlock } = useBlockManager();

  // 打开块文档
  useEffect(() => {
    openBlockDoc(blockId);
    return () => closeBlockDoc();
  }, [blockId]);

  // 渲染块内容
  return (
    <Layout className="block-page">
      <Header style={{ background: '#fff', padding: 0 }}>
        <div style={{ padding: '0 24px' }}>
          <h2>{
            openBlock?.type === BlockType.DOC 
              ? (openBlock.properties as any)?.title || '文档详情'
              : '文档详情'
          }</h2>
          <p>ID: {blockId}</p>
        </div>
      </Header>
      <Content style={{ padding: '0 24px' }}>
        {openBlock?.id === blockId && children}
      </Content>
    </Layout>
  );
};

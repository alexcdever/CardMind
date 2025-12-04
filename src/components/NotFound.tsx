import React from 'react'
import { Layout, Button, Typography, Result } from 'antd'
import { ArrowLeftOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'

const { Header, Content } = Layout
const { Title } = Typography

const NotFound: React.FC = () => {
  const navigate = useNavigate()

  return (
    <Layout className="min-h-screen">
      <Header className="bg-white shadow-sm px-6">
        <div className="flex items-center h-full">
          <Button 
            type="primary" 
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate('/')}
            className="mr-4"
            size="middle"
          >
            返回首页
          </Button>
          <Title level={4} className="m-0 text-primary">CardMind</Title>
        </div>
      </Header>

      <Content className="p-6">
        <div className="max-w-4xl mx-auto text-center py-12">
          <Result
            status="404"
            title="404"
            subTitle="抱歉，您访问的页面不存在"
            extra={
              <Button type="primary" onClick={() => navigate('/')}>
                返回首页
              </Button>
            }
          />
        </div>
      </Content>
    </Layout>
  )
}

export default NotFound

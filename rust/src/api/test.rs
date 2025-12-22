// API服务测试用例

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::impl_::ApiService;
    
    #[tokio::test]
    async fn test_api_service_new() {
        // 测试创建API服务实例
        let api_service = ApiService::new(":memory:").await;
        assert!(api_service.is_ok());
    }
}

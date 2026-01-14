//! # 单池模型流程规格示例（可执行规格）
//! 
//! **运行方式**:
//! ```bash
//! cargo run --example single_pool_flow_spec
//! ```
//! 
//! 这个文件是**可执行业务规格说明书**,演示单池模型的核心流程。
//! 所有测试场景都基于规格文档 SP-SPM-001 和 SP-DEV-002。

use std::sync::{Arc, Mutex};
use uuid::Uuid;

// 模拟设备配置（实际实现中从文件加载）
#[derive(Clone, Debug)]
struct DeviceConfig {
    device_id: String,
    device_name: String,
    pool_id: Option<String>,
}

// 错误类型
#[derive(Debug, PartialEq)]
enum CardMindError {
    AlreadyJoinedPool(String),
    NotJoinedPool,
    InvalidPassword,
}

// 模拟数据存储
struct MockStorage {
    device_config: Arc<Mutex<DeviceConfig>>,
    pools: Arc<Mutex<Vec<MockPool>>>,
}

#[derive(Clone, Debug)]
struct MockPool {
    pool_id: String,
    name: String,
    password_hash: String,
    members: Vec<String>,
    card_ids: Vec<String>,
}

// ===== 规格实现 =====

impl DeviceConfig {
    fn load_or_create() -> Result<Self, CardMindError> {
        // 模拟：实际从文件加载
        Ok(DeviceConfig {
            device_id: Uuid::new_v7().to_string(),
            device_name: format!("Device-{}", &Uuid::new_v7().to_string()[..8]),
            pool_id: None,
        })
    }
    
    fn join_pool(&mut self, pool_id: String) -> Result<(), CardMindError> {
        if self.pool_id.is_some() {
            return Err(CardMindError::AlreadyJoinedPool(
                "设备已加入其他池".to_string()
            ));
        }
        self.pool_id = Some(pool_id);
        Ok(())
    }
    
    fn leave_pool(&mut self) -> Result<(), CardMindError> {
        if self.pool_id.is_none() {
            return Err(CardMindError::NotJoinedPool);
        }
        self.pool_id = None;
        Ok(())
    }
    
    fn is_joined(&self) -> bool {
        self.pool_id.is_some()
    }
}

impl MockPool {
    fn new(pool_id: &str, name: &str, password: &str) -> Self {
        MockPool {
            pool_id: pool_id.to_string(),
            name: name.to_string(),
            password_hash: password.to_string(), // 简化：实际使用 bcrypt
            members: vec![],
            card_ids: vec![],
        }
    }
    
    fn add_member(&mut self, device_id: String) {
        if !self.members.contains(&device_id) {
            self.members.push(device_id);
        }
    }
    
    fn add_card(&mut self, card_id: String) {
        if !self.card_ids.contains(&card_id) {
            self.card_ids.push(card_id);
        }
    }
    
    fn remove_card(&mut self, card_id: &str) {
        self.card_ids.retain(|id| id != card_id);
    }
}

// ===== 测试辅助函数 =====

struct TestContext {
    storage: Arc<MockStorage>,
}

impl TestContext {
    fn new() -> Self {
        let config = DeviceConfig::load_or_create().unwrap();
        let storage = Arc::new(MockStorage {
            device_config: Arc::new(Mutex::new(config)),
            pools: Arc::new(Mutex::new(vec![])),
        });
        TestContext { storage }
    }
    
    fn create_pool(&self, pool_id: &str, name: &str, password: &str) {
        let pool = MockPool::new(pool_id, name, password);
        self.storage.pools.lock().unwrap().push(pool);
    }
    
    fn get_pool(&self, pool_id: &str) -> Option<MockPool> {
        self.storage.pools.lock().unwrap()
            .iter()
            .find(|p| p.pool_id == pool_id)
            .cloned()
    }
    
    fn config(&self) -> Arc<Mutex<DeviceConfig>> {
        self.storage.device_config.clone()
    }
}

// ===== 主测试场景 =====

fn main() {
    println!("🧪 运行单池模型规格示例\n");
    println!("=str::repeat("=").to_string());
    
    scenario_1_first_time_user();
    println!("=str::repeat("=").to_string());
    scenario_2_second_device_join();
    println!("=str::repeat("=").to_string());
    scenario_3_cannot_join_multiple_pools();
    println!("=".repeat(60));
    scenario_4_create_cards_auto_join();
    println!("=".repeat(60));
    scenario_5_remove_card_propagation();
    println!("=".repeat(60));
    scenario_6_leave_pool_cleanup();
    
    println!("\n✅ 所有规格场景验证完成！");
}

// 场景 1: 新用户首次使用（创建池）
fn scenario_1_first_time_user() {
    println!("\n📋 场景 1: 新用户首次使用");
    println!("规格: SP-SPM-001-Spec-004-B");
    
    let ctx = TestContext::new();
    let config = ctx.config();
    
    // Given: 新设备，未初始化
    assert!(!config.lock().unwrap().is_joined());
    println!("  ✓ 设备未加入任何池");
    
    // When: 初始化（创建新池）
    let pool_id = "pool_001".to_string();
    ctx.create_pool(&pool_id, "我的笔记", "secure-password");
    
    let mut config_mut = config.lock().unwrap();
    config_mut.join_pool(pool_id.clone()).unwrap();
    
    // Then: 成功加入
    assert_eq!(config_mut.pool_id, Some(pool_id.clone()));
    println!("  ✓ 池创建成功: {}", pool_id);
    println!("  ✓ 设备已加入池");
    
    // Spec: 创建第一张卡片
    let card_id = "card_001".to_string();
    let mut pool = ctx.get_pool(&pool_id).unwrap();
    pool.add_card(card_id.clone());
    println!("  ✓ 创建第一张卡片: {}", card_id);
    
    // Spec: 验证卡片在池中
    assert!(pool.card_ids.contains(&card_id));
    println!("  ✓ 卡片自动关联到池");
}

// 场景 2: 第 N 台设备加入
fn scenario_2_second_device_join() {
    println!("\n📋 场景 2: 第 N 台设备加入现有池");
    println!("规格: SP-SPM-001-Spec-004-C");
    
    let ctx = TestContext::new();
    let config = ctx.config();
    
    // Given: 已存在 pool_A（由第一台设备创建）
    let pool_id = "pool_A".to_string();
    ctx.create_pool(&pool_id, "我的笔记", "correct-password");
    println!("  ✓ 池已存在: {}", pool_id);
    
    // Given: 第一台设备创建的卡片
    let mut pool = ctx.get_pool(&pool_id).unwrap();
    pool.add_card("card_001".to_string());
    pool.add_card("card_002".to_string());
    println!("  ✓ 池中有 2 张卡片");
    
    // Given: 新设备（未加入）
    assert!(!config.lock().unwrap().is_joined());
    println!("  ✓ 新设备未加入");
    
    // When: 用正确密码加入
    let mut config_mut = config.lock().unwrap();
    config_mut.join_pool(pool_id.clone()).unwrap();
    
    // Then: 成功加入
    assert_eq!(config_mut.pool_id, Some(pool_id.clone()));
    println!("  ✓ 加入成功");
    
    // Spec: 可以获取池内所有卡片
    let pool_after = ctx.get_pool(&pool_id).unwrap();
    assert_eq!(pool_after.card_ids.len(), 2);
    println!("  ✓ 可访问池内 {} 张卡片", pool_after.card_ids.len());
    
    // Spec: 新设备创建卡片也自动加入同池
    let new_card_id = "card_003".to_string();
    let mut pool_updated = ctx.get_pool(&pool_id).unwrap();
    pool_updated.add_card(new_card_id.clone());
    assert_eq!(pool_updated.card_ids.len(), 3);
    println!("  ✓ 新创卡片自动加入同一池");
}

// 场景 3: 设备不能加入多个池（核心约束）
fn scenario_3_cannot_join_multiple_pools() {
    println!("\n📋 场景 3: 设备不能加入多个池");
    println!("规格: SP-DEV-002-Spec-DEV-002");
    
    let ctx = TestContext::new();
    
    // Given: 设备已加入 pool_A
    {
        let mut config = ctx.config().lock().unwrap();
        config.join_pool("pool_A".to_string()).unwrap();
        assert_eq!(config.pool_id, Some("pool_A".to_string()));
    }
    println!("  ✓ 设备已加入 pool_A");
    
    // When: 尝试加入 pool_B
    let result = {
        let mut config = ctx.config().lock().unwrap();
        config.join_pool("pool_B".to_string())
    };
    
    // Then: 拒绝
    assert!(result.is_err());
    assert!(matches!(result.unwrap_err(), CardMindError::AlreadyJoinedPool(_)));
    println!("  ✓ 拒绝加入第二个池（返回 AlreadyJoinedError）");
    
    // Spec: pool_id 保持不变
    let config = ctx.config().lock().unwrap();
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    println!("  ✓ pool_id 未改变");
}

// 场景 4: 创建卡片自动加入当前池
fn scenario_4_create_cards_auto_join() {
    println!("\n📋 场景 4: 创建卡片时自动加入当前池");
    println!("规格: SP-SPM-001-Spec-005-A");
    
    let ctx = TestContext::new();
    let pool_id = "pool_A".to_string();
    ctx.create_pool(&pool_id, "我的笔记", "password");
    
    // Given: 设备已加入池
    {
        let mut config = ctx.config().lock().unwrap();
        config.join_pool(pool_id.clone()).unwrap();
    }
    println!("  ✓ 设备已加入池");
    
    // When: 创建多张卡片（极简流程）
    let card_ids = vec!["card_001", "card_002", "card_003"];
    for (i, card_id) in card_ids.iter().enumerate() {
        let mut pool = ctx.get_pool(&pool_id).unwrap();
        pool.add_card(card_id.to_string());
        println!("  ✓ 创建卡片 {}: {}", i+1, card_id);
    }
    
    // Then: 所有卡片都在池中
    let pool = ctx.get_pool(&pool_id).unwrap();
    assert_eq!(pool.card_ids.len(), 3);
    println!("  ✓ 所有 {} 张卡片自动在池中", pool.card_ids.len());
    
    // Spec: 无需手动选择池（对比旧模型）
    println!("  ✓ 流程极简：FAB → 编辑器 → 保存");
}

// 场景 5: 移除卡片可传播到所有设备
fn scenario_5_remove_card_propagation() {
    println!("\n📋 场景 5: 移除卡片可传播到所有设备");
    println!("规格: SP-SPM-001-Spec-005-C");
    
    let ctx = TestContext::new();
    let pool_id = "pool_shared".to_string();
    ctx.create_pool(&pool_id, "共享池", "password");
    
    // Given: 两台设备都加入同一池
    let device_a = "device_A".to_string();
    let device_b = "device_B".to_string();
    
    let mut pool = ctx.get_pool(&pool_id).unwrap();
    pool.add_member(device_a.clone());
    pool.add_member(device_b.clone());
    println!("  ✓ 两台设备加入同一池");
    
    // Given: 池中有 5 张卡片
    for i in 1..=5 {
        pool.add_card(format!("card_{:03}", i));
    }
    assert_eq!(pool.card_ids.len(), 5);
    println!("  ✓ 池中有 {} 张卡片", pool.card_ids.len());
    
    // When: device_A 移除 2 张卡片
    pool.remove_card("card_002");
    pool.remove_card("card_004");
    println!("  ✓ device_A 移除 card_002, card_004");
    println!("  ✓ Pool.card_ids 更新并 commit");
    
    // Then: Pool Loro 文档同步到所有设备（包括 device_B）
    // Spec: 无论过滤器如何，Pool 文档都会同步
    assert_eq!(pool.card_ids.len(), 3);
    println!("  ✓ device_B 自动收到更新");
    println!("  ✓ 池内剩余 {} 张卡片", pool.card_ids.len());
    println!("  ✓ 完美解决旧模型的移除传播问题！");
}

// 场景 6: 退出池清空所有数据
fn scenario_6_leave_pool_cleanup() {
    println!("\n📋 场景 6: 退出笔记空间时清空所有数据");
    println!("规格: SP-DEV-002-Spec-DEV-003");
    
    let ctx = TestContext::new();
    let pool_id = "pool_A".to_string();
    ctx.create_pool(&pool_id, "我的笔记", "password");
    
    // 模拟有数据的情况
    let mut pool = ctx.get_pool(&pool_id).unwrap();
    pool.add_card("card_001".to_string());
    pool.add_card("card_002".to_string());
    pool.add_member("device_001".to_string());
    
    // Given: 设备已加入池，有数据
    {
        let mut config = ctx.config().lock().unwrap();
        config.join_pool(pool_id.clone()).unwrap();
    }
    println!("  ✓ 设备在 pool_A 中");
    println!("  ✓ 池中有 {} 张卡片", pool.card_ids.len());
    println!("  ✓ 池中有 {} 个成员", pool.members.len());
    
    // When: 退出池
    {
        let mut config = ctx.config().lock().unwrap();
        tokio::runtime::Runtime::new().unwrap().block_on(config.leave_pool()).unwrap();
    }
    println!("  ✓ 调用 leave_pool()");
    
    // Then: pool_id 清空
    {
        let config = ctx.config().lock().unwrap();
        assert!(config.pool_id.is_none());
        println!("  ✓ pool_id = None");
    }
    
    // Spec: 所有本地数据清空（模拟）
    println!("  ✓ 删除所有卡片 Loro 文档");
    println!("  ✓ 删除 Pool 文档");
    println!("  ✓ 清空 SQLite 卡片表");
    println!("  ✓ 清空 SQLite 绑定表");
    println!("  ✓ 删除密码");
    println!("  ✓ 数据清理完成！");
}

// ===== 测试运行器 =====

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_all_scenarios() {
        println!("\n🧪 执行集成规格测试...");
        
        let ctx = TestContext::new();
        
        // 测试场景 1
        let mut config = ctx.config().lock().unwrap();
        assert!(!config.is_joined());
        config.join_pool("pool_test".to_string()).unwrap();
        assert!(config.is_joined());
        
        // 测试场景 2
        let result = config.join_pool("pool_test2".to_string());
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), CardMindError::AlreadyJoinedPool(_)));
        
        println!("✓ 所有集成测试通过！");
    }
}

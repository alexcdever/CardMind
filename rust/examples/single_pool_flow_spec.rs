#![allow(clippy::unnecessary_wraps)]
#![allow(clippy::unused_self)]

use std::sync::{Arc, Mutex};

#[allow(dead_code)]
struct DeviceConfig {
    device_id: String,
    pool_id: Option<String>,
}

impl DeviceConfig {
    fn new() -> Self {
        Self {
            device_id: "test-device".to_string(),
            pool_id: None,
        }
    }

    const fn is_joined(&self) -> bool {
        self.pool_id.is_some()
    }

    fn join_pool(&mut self, pool_id: String) -> Result<(), String> {
        self.pool_id = Some(pool_id);
        Ok(())
    }
}

#[derive(Clone)]
#[allow(dead_code)]
struct Pool {
    id: String,
    card_ids: Vec<String>,
}

impl Pool {
    fn new(id: String, _name: String) -> Self {
        Self {
            id,
            card_ids: Vec::new(),
        }
    }

    fn add_card(&mut self, card_id: String) {
        self.card_ids.push(card_id);
    }
}

struct TestContext {
    pools: Arc<Mutex<Vec<Pool>>>,
}

impl TestContext {
    fn new() -> Self {
        Self {
            pools: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn config(&self) -> DeviceConfig {
        DeviceConfig::new()
    }

    fn create_pool(&self, id: &str, name: &str, _password: &str) -> Pool {
        let pool = Pool::new(id.to_string(), name.to_string());
        self.pools.lock().unwrap().push(pool.clone());
        pool
    }
}

fn main() {
    std::println!("Single Pool Model Spec Examples");
    scenario_1_first_time_user();
    scenario_2_existing_pool_join();
    scenario_3_cannot_join_multiple();
    std::println!("All scenarios completed");
}

fn scenario_1_first_time_user() {
    println!("[SCENARIO 1] First-time user creating pool");
    let ctx = TestContext::new();
    let mut config = ctx.config();

    assert!(!config.is_joined());

    config.join_pool("pool_001".to_string()).unwrap();
    assert_eq!(config.pool_id, Some("pool_001".to_string()));

    let mut pool = ctx.create_pool("pool_001", "My Notes", "secret123");
    pool.add_card("card_001".to_string());

    println!("[PASS] Device joined pool");
}

fn scenario_2_existing_pool_join() {
    println!("[SCENARIO 2] Nth device joins existing pool");
    let ctx = TestContext::new();
    let mut pool = ctx.create_pool("existing", "Existing Pool", "secret123");

    pool.add_card("card_001".to_string());
    pool.add_card("card_002".to_string());

    let mut config = ctx.config();
    config.join_pool("existing".to_string()).unwrap();
    assert_eq!(config.pool_id, Some("existing".to_string()));
    assert_eq!(pool.card_ids.len(), 2);

    println!("[PASS] Device joined existing pool");
}

fn scenario_3_cannot_join_multiple() {
    println!("[SCENARIO 3] Device cannot join multiple pools");
    let ctx = TestContext::new();
    let mut config = ctx.config();

    config.join_pool("pool_A".to_string()).unwrap();
    let result = config.join_pool("pool_B".to_string());

    assert!(result.is_err());
    assert_eq!(config.pool_id, Some("pool_A".to_string()));

    println!("[PASS] Rejected joining second pool");
}

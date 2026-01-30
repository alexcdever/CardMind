#![allow(clippy::unnecessary_wraps)]
#![allow(unused_imports)]

use std::sync::{Arc, Mutex};

struct DeviceConfig {
    pool_id: Option<String>,
}

impl DeviceConfig {
    const fn new() -> Self {
        Self { pool_id: None }
    }

    const fn is_joined(&self) -> bool {
        self.pool_id.is_some()
    }

    fn join_pool(&mut self, pool_id: String) -> Result<(), ()> {
        self.pool_id = Some(pool_id);
        Ok(())
    }
}

fn main() {
    println!("Single Pool Model Spec Examples");

    let mut config = DeviceConfig::new();
    assert!(!config.is_joined());

    config.join_pool("pool-001".to_string()).unwrap();
    assert_eq!(config.pool_id, Some("pool-001".to_string()));

    println!("[SCENARIO 1] Device joined pool");

    let result = config.join_pool("pool-002".to_string());
    assert!(result.is_err());

    println!("[SCENARIO 2] Cannot join multiple pools");
    println!("[PASS] Spec verified");
}

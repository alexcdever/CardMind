#![no_main]

use cardmind_rust::security::password::derive_pool_hash;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if data.is_empty() {
        return;
    }
    let mid = data.len() / 2;
    let pool_id = String::from_utf8_lossy(&data[..mid]);
    let password = String::from_utf8_lossy(&data[mid..]);
    let _ = derive_pool_hash(pool_id.as_ref(), password.as_ref());
});

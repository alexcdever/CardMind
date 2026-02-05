#![no_main]

use cardmind_rust::models::pool::Pool;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &str| {
    let _ = Pool::validate_name(data);
    let _ = Pool::validate_password(data);
});

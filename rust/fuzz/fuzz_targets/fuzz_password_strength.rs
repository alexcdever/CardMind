#![no_main]

use cardmind_rust::security::password::evaluate_password_strength;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &str| {
    let _ = evaluate_password_strength(data);
});

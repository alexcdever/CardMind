use uuid::Uuid;

/// Generate a new UUID v7 (time-ordered)
///
/// UUID v7 is time-ordered and monotonic, making it perfect for
/// distributed systems and CRDT scenarios.
///
/// # Returns
///
/// A new UUID v7 as a String
#[must_use]
pub fn generate_uuid_v7() -> String {
    Uuid::now_v7().to_string()
}

/// Validate if a string is a valid UUID
///
/// # Arguments
///
/// * `id` - The UUID string to validate
///
/// # Returns
///
/// `true` if valid, `false` otherwise
#[must_use]
pub fn is_valid_uuid(id: &str) -> bool {
    Uuid::parse_str(id).is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_should_generate_uuid_v7() {
        let id = generate_uuid_v7();
        assert!(is_valid_uuid(&id));
        assert_eq!(id.len(), 36); // UUID format: 8-4-4-4-12
    }

    #[test]
    fn it_should_uuid_v7_is_time_ordered() {
        let id1 = generate_uuid_v7();
        std::thread::sleep(std::time::Duration::from_millis(10));
        let id2 = generate_uuid_v7();

        // UUID v7 should be lexicographically ordered by time
        assert!(id1 < id2);
    }

    #[test]
    fn it_should_is_valid_uuid() {
        assert!(is_valid_uuid("550e8400-e29b-41d4-a716-446655440000"));
        assert!(!is_valid_uuid("not-a-uuid"));
        assert!(!is_valid_uuid(""));
    }
}

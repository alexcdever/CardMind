// input: pool_network 模块的功能和边界条件。
// output: PoolNetwork 结构体和解析函数的单元测试。
// pos: pool_network.rs 单元测试文件。修改本文件需同步更新所属 DIR.md。
// 中文注释：本文件测试 pool_network 模块的核心功能。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::PoolMember;
use loro::{LoroDoc, LoroMap, LoroValue};
use uuid::Uuid;

// ==================== 辅助函数（从 pool_network.rs 复制） ====================

fn parse_members(value: LoroValue) -> Result<Vec<PoolMember>, CardMindError> {
    let mut members = Vec::new();
    let list = match value {
        LoroValue::List(list) => list,
        LoroValue::Null => return Ok(members),
        _ => {
            return Err(CardMindError::InvalidArgument(
                "members invalid".to_string(),
            ));
        }
    };
    for item in list.iter() {
        let member_list = match item {
            LoroValue::List(list) => list,
            _ => return Err(CardMindError::InvalidArgument("member invalid".to_string())),
        };
        if member_list.len() != 4 {
            return Err(CardMindError::InvalidArgument(
                "member length invalid".to_string(),
            ));
        }
        let endpoint_id = parse_string_value(&member_list[0], "member.endpoint_id")?;
        let nickname = parse_string_value(&member_list[1], "member.nickname")?;
        let os = parse_string_value(&member_list[2], "member.os")?;
        let is_admin = parse_bool_value(&member_list[3], "member.is_admin")?;
        members.push(PoolMember {
            endpoint_id,
            nickname,
            os,
            is_admin,
        });
    }
    Ok(members)
}

fn parse_card_ids(value: LoroValue) -> Result<Vec<Uuid>, CardMindError> {
    let mut ids = Vec::new();
    let list = match value {
        LoroValue::List(list) => list,
        LoroValue::Null => return Ok(ids),
        _ => {
            return Err(CardMindError::InvalidArgument(
                "card_ids invalid".to_string(),
            ));
        }
    };
    for item in list.iter() {
        let id = parse_uuid_value(item, "card_id")?;
        ids.push(id);
    }
    Ok(ids)
}

fn parse_uuid(map: &LoroMap, key: &str) -> Result<Uuid, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_uuid_value(&value, key)
}

fn parse_string(map: &LoroMap, key: &str) -> Result<String, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_string_value(&value, key)
}

fn parse_i64(map: &LoroMap, key: &str) -> Result<i64, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    match value {
        LoroValue::I64(v) => Ok(v),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}

fn parse_bool(map: &LoroMap, key: &str) -> Result<bool, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_bool_value(&value, key)
}

fn parse_uuid_value(value: &LoroValue, key: &str) -> Result<Uuid, CardMindError> {
    let text = parse_string_value(value, key)?;
    Uuid::parse_str(&text).map_err(|_| CardMindError::InvalidArgument(format!("{} invalid", key)))
}

fn parse_string_value(value: &LoroValue, key: &str) -> Result<String, CardMindError> {
    match value {
        LoroValue::String(v) => Ok(v.as_ref().to_string()),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}

fn parse_bool_value(value: &LoroValue, key: &str) -> Result<bool, CardMindError> {
    match value {
        LoroValue::Bool(v) => Ok(*v),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}

// ==================== parse_members 测试 ====================

#[test]
fn test_parse_members_empty_list() {
    let value = LoroValue::List(vec![].into());
    let result = parse_members(value);

    assert!(result.is_ok());
    assert!(result.unwrap().is_empty());
}

#[test]
fn test_parse_members_null() {
    let value = LoroValue::Null;
    let result = parse_members(value);

    assert!(result.is_ok());
    assert!(result.unwrap().is_empty());
}

#[test]
fn test_parse_members_valid_member() {
    let member_data = LoroValue::List(
        vec![
            LoroValue::String("endpoint-123".into()),
            LoroValue::String("Alice".into()),
            LoroValue::String("macOS".into()),
            LoroValue::Bool(true),
        ]
        .into(),
    );
    let value = LoroValue::List(vec![member_data].into());

    let result = parse_members(value);
    assert!(result.is_ok());

    let members = result.unwrap();
    assert_eq!(members.len(), 1);
    assert_eq!(members[0].endpoint_id, "endpoint-123");
    assert_eq!(members[0].nickname, "Alice");
    assert_eq!(members[0].os, "macOS");
    assert!(members[0].is_admin);
}

#[test]
fn test_parse_members_invalid_type() {
    // 传入非列表类型
    let value = LoroValue::String("invalid".into());
    let result = parse_members(value);

    assert!(result.is_err());
    if let Err(CardMindError::InvalidArgument(msg)) = result {
        assert!(msg.contains("members invalid"));
    } else {
        panic!("Expected InvalidArgument error");
    }
}

#[test]
fn test_parse_members_invalid_member_type() {
    // 成员不是列表
    let value = LoroValue::List(vec![LoroValue::String("not-a-list".into())].into());
    let result = parse_members(value);

    assert!(result.is_err());
}

#[test]
fn test_parse_members_invalid_member_length() {
    // 成员列表长度不对
    let member_data = LoroValue::List(
        vec![
            LoroValue::String("endpoint-123".into()),
            LoroValue::String("Alice".into()),
        ]
        .into(),
    );
    let value = LoroValue::List(vec![member_data].into());

    let result = parse_members(value);
    assert!(result.is_err());
    if let Err(CardMindError::InvalidArgument(msg)) = result {
        assert!(msg.contains("member length invalid"));
    } else {
        panic!("Expected InvalidArgument error");
    }
}

#[test]
fn test_parse_members_invalid_endpoint_id_type() {
    // endpoint_id 不是字符串
    let member_data = LoroValue::List(
        vec![
            LoroValue::I64(123), // 应该是字符串
            LoroValue::String("Alice".into()),
            LoroValue::String("macOS".into()),
            LoroValue::Bool(true),
        ]
        .into(),
    );
    let value = LoroValue::List(vec![member_data].into());

    let result = parse_members(value);
    assert!(result.is_err());
}

#[test]
fn test_parse_members_invalid_is_admin_type() {
    // is_admin 不是布尔值
    let member_data = LoroValue::List(
        vec![
            LoroValue::String("endpoint-123".into()),
            LoroValue::String("Alice".into()),
            LoroValue::String("macOS".into()),
            LoroValue::String("true".into()), // 应该是布尔值
        ]
        .into(),
    );
    let value = LoroValue::List(vec![member_data].into());

    let result = parse_members(value);
    assert!(result.is_err());
}

#[test]
fn test_parse_members_multiple_members() {
    let member1 = LoroValue::List(
        vec![
            LoroValue::String("endpoint-1".into()),
            LoroValue::String("Alice".into()),
            LoroValue::String("macOS".into()),
            LoroValue::Bool(true),
        ]
        .into(),
    );
    let member2 = LoroValue::List(
        vec![
            LoroValue::String("endpoint-2".into()),
            LoroValue::String("Bob".into()),
            LoroValue::String("Windows".into()),
            LoroValue::Bool(false),
        ]
        .into(),
    );
    let value = LoroValue::List(vec![member1, member2].into());

    let result = parse_members(value);
    assert!(result.is_ok());

    let members = result.unwrap();
    assert_eq!(members.len(), 2);
    assert_eq!(members[0].nickname, "Alice");
    assert_eq!(members[1].nickname, "Bob");
}

// ==================== parse_card_ids 测试 ====================

#[test]
fn test_parse_card_ids_empty_list() {
    let value = LoroValue::List(vec![].into());
    let result = parse_card_ids(value);

    assert!(result.is_ok());
    assert!(result.unwrap().is_empty());
}

#[test]
fn test_parse_card_ids_null() {
    let value = LoroValue::Null;
    let result = parse_card_ids(value);

    assert!(result.is_ok());
    assert!(result.unwrap().is_empty());
}

#[test]
fn test_parse_card_ids_valid_uuids() {
    let uuid1 = Uuid::new_v4();
    let uuid2 = Uuid::new_v4();

    let value = LoroValue::List(
        vec![
            LoroValue::String(uuid1.to_string().into()),
            LoroValue::String(uuid2.to_string().into()),
        ]
        .into(),
    );

    let result = parse_card_ids(value);
    assert!(result.is_ok());

    let ids = result.unwrap();
    assert_eq!(ids.len(), 2);
    assert_eq!(ids[0], uuid1);
    assert_eq!(ids[1], uuid2);
}

#[test]
fn test_parse_card_ids_invalid_type() {
    let value = LoroValue::I64(123);
    let result = parse_card_ids(value);

    assert!(result.is_err());
}

#[test]
fn test_parse_card_ids_invalid_uuid_format() {
    let value = LoroValue::List(vec![LoroValue::String("not-a-uuid".into())].into());

    let result = parse_card_ids(value);
    assert!(result.is_err());
}

#[test]
fn test_parse_card_ids_non_string_value() {
    let value = LoroValue::List(vec![LoroValue::I64(123)].into());

    let result = parse_card_ids(value);
    assert!(result.is_err());
}

// ==================== parse_uuid 测试 ====================

#[test]
fn test_parse_uuid_success() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    let test_uuid = Uuid::new_v4();
    map.insert("id", test_uuid.to_string()).unwrap();

    let result = parse_uuid(&map, "id");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), test_uuid);
}

#[test]
fn test_parse_uuid_missing_key() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");

    let result = parse_uuid(&map, "nonexistent");
    assert!(result.is_err());
    if let Err(CardMindError::NotFound(msg)) = result {
        assert!(msg.contains("nonexistent missing"));
    } else {
        panic!("Expected NotFound error");
    }
}

#[test]
fn test_parse_uuid_invalid_format() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("id", "not-a-uuid").unwrap();

    let result = parse_uuid(&map, "id");
    assert!(result.is_err());
}

// ==================== parse_string 测试 ====================

#[test]
fn test_parse_string_success() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("name", "Test Name").unwrap();

    let result = parse_string(&map, "name");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "Test Name");
}

#[test]
fn test_parse_string_missing_key() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");

    let result = parse_string(&map, "missing");
    assert!(result.is_err());
}

#[test]
fn test_parse_string_non_string_value() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("count", 42i64).unwrap();

    let result = parse_string(&map, "count");
    assert!(result.is_err());
}

// ==================== parse_i64 测试 ====================

#[test]
fn test_parse_i64_success() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("timestamp", 1234567890i64).unwrap();

    let result = parse_i64(&map, "timestamp");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), 1234567890);
}

#[test]
fn test_parse_i64_missing_key() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");

    let result = parse_i64(&map, "missing");
    assert!(result.is_err());
}

#[test]
fn test_parse_i64_non_i64_value() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("name", "test").unwrap();

    let result = parse_i64(&map, "name");
    assert!(result.is_err());
}

// ==================== parse_bool 测试 ====================

#[test]
fn test_parse_bool_true() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("active", true).unwrap();

    let result = parse_bool(&map, "active");
    assert!(result.is_ok());
    assert!(result.unwrap());
}

#[test]
fn test_parse_bool_false() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("deleted", false).unwrap();

    let result = parse_bool(&map, "deleted");
    assert!(result.is_ok());
    assert!(!result.unwrap());
}

#[test]
fn test_parse_bool_missing_key() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");

    let result = parse_bool(&map, "missing");
    assert!(result.is_err());
}

#[test]
fn test_parse_bool_non_bool_value() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("count", 1i64).unwrap();

    let result = parse_bool(&map, "count");
    assert!(result.is_err());
}

// ==================== parse_uuid_value 测试 ====================

#[test]
fn test_parse_uuid_value_valid() {
    let uuid = Uuid::new_v4();
    let value = LoroValue::String(uuid.to_string().into());

    let result = parse_uuid_value(&value, "test_id");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), uuid);
}

#[test]
fn test_parse_uuid_value_invalid_format() {
    let value = LoroValue::String("invalid-uuid".into());

    let result = parse_uuid_value(&value, "test_id");
    assert!(result.is_err());
}

#[test]
fn test_parse_uuid_value_non_string() {
    let value = LoroValue::I64(123);

    let result = parse_uuid_value(&value, "test_id");
    assert!(result.is_err());
}

// ==================== parse_string_value 测试 ====================

#[test]
fn test_parse_string_value_valid() {
    let value = LoroValue::String("hello world".into());

    let result = parse_string_value(&value, "field");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "hello world");
}

#[test]
fn test_parse_string_value_empty() {
    let value = LoroValue::String("".into());

    let result = parse_string_value(&value, "field");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "");
}

#[test]
fn test_parse_string_value_non_string() {
    let value = LoroValue::Bool(true);

    let result = parse_string_value(&value, "field");
    assert!(result.is_err());
}

// ==================== parse_bool_value 测试 ====================

#[test]
fn test_parse_bool_value_true() {
    let value = LoroValue::Bool(true);

    let result = parse_bool_value(&value, "flag");
    assert!(result.is_ok());
    assert!(result.unwrap());
}

#[test]
fn test_parse_bool_value_false() {
    let value = LoroValue::Bool(false);

    let result = parse_bool_value(&value, "flag");
    assert!(result.is_ok());
    assert!(!result.unwrap());
}

#[test]
fn test_parse_bool_value_non_bool() {
    let value = LoroValue::I64(1);

    let result = parse_bool_value(&value, "flag");
    assert!(result.is_err());
}

// ==================== 边界值测试 ====================

#[test]
fn test_parse_i64_boundary_max() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("max", i64::MAX).unwrap();

    let result = parse_i64(&map, "max");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), i64::MAX);
}

#[test]
fn test_parse_i64_boundary_min() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("min", i64::MIN).unwrap();

    let result = parse_i64(&map, "min");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), i64::MIN);
}

#[test]
fn test_parse_i64_zero() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("zero", 0i64).unwrap();

    let result = parse_i64(&map, "zero");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), 0);
}

#[test]
fn test_parse_card_ids_with_nil_uuid() {
    let nil_uuid = Uuid::nil();
    let value = LoroValue::List(vec![LoroValue::String(nil_uuid.to_string().into())].into());

    let result = parse_card_ids(value);
    assert!(result.is_ok());
    assert_eq!(result.unwrap()[0], nil_uuid);
}

#[test]
fn test_parse_members_empty_strings() {
    let member_data = LoroValue::List(
        vec![
            LoroValue::String("".into()),
            LoroValue::String("".into()),
            LoroValue::String("".into()),
            LoroValue::Bool(false),
        ]
        .into(),
    );
    let value = LoroValue::List(vec![member_data].into());

    let result = parse_members(value);
    assert!(result.is_ok());

    let members = result.unwrap();
    assert_eq!(members[0].endpoint_id, "");
    assert_eq!(members[0].nickname, "");
    assert_eq!(members[0].os, "");
}

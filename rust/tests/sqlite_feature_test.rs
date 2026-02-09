#![allow(clippy::similar_names)]

/// `SQLite集成测试`
///
/// 测试SQLite表创建、CRUD操作和数据库初始化功能
///
/// 测试内容:
/// - `SQLite数据库创建和连接`
/// - cards表创建和schema验证
/// - `SQLite优化参数配置`
/// - 基础CRUD操作
///
/// 注意: 所有测试使用内存数据库，不创建实际文件
use cardmind_rust::models::card::{Card, OwnerType};
use cardmind_rust::models::error::CardMindError;
use cardmind_rust::utils::uuid_v7::generate_uuid_v7;
use rusqlite::{Connection, Result as SqliteResult};

const fn require_card(
    result: std::result::Result<Card, CardMindError>,
) -> std::result::Result<Card, CardMindError> {
    result
}

fn default_peer_id() -> String {
    "12D3KooWTestPeerId".to_string()
}

fn parse_owner_type(value: String) -> SqliteResult<OwnerType> {
    OwnerType::try_from(value.as_str()).map_err(|err| {
        rusqlite::Error::FromSqlConversionFailure(6, rusqlite::types::Type::Text, Box::new(err))
    })
}

// ==================== 1. 表创建测试 ====================

/// 测试: `SQLite数据库连接创建`
#[test]
fn it_should_create_in_memory_db() {
    // Given: 无需前置条件

    // When: 创建内存数据库连接
    let conn = Connection::open_in_memory();

    // Then: 应该成功创建
    assert!(conn.is_ok(), "应该能成功创建内存数据库");
}

/// 测试: cards表创建
///
/// 验收标准:
/// - 表创建成功
/// - 可以查询表结构
#[test]
fn it_should_create_cards_table() {
    // Given: 一个内存数据库连接
    let conn = Connection::open_in_memory().unwrap();

    // When: 执行表创建 SQL
    let result = create_cards_table(&conn);

    // Then: 表应该创建成功，且可以查询到
    assert!(result.is_ok(), "cards表应该创建成功");

    let mut stmt = conn
        .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='cards'")
        .unwrap();
    let table_exists: bool = stmt.exists([]).unwrap();
    assert!(table_exists, "cards表应该存在");
}

/// 测试: 表结构验证
///
/// 验收标准:
/// - 所有字段存在且类型正确
/// - id为主键
/// - 索引创建正确
#[test]
fn it_should_table_schema_validation() {
    // Given: 一个包含 cards 表的内存数据库
    let conn = Connection::open_in_memory().unwrap();
    create_cards_table(&conn).unwrap();

    // When: 查询表结构信息
    let mut stmt = conn.prepare("PRAGMA table_info(cards)").unwrap();
    let columns: Vec<(i32, String, String, i32, Option<String>, i32)> = stmt
        .query_map([], |row| {
            Ok((
                row.get(0)?, // cid
                row.get(1)?, // name
                row.get(2)?, // type
                row.get(3)?, // notnull
                row.get(4)?, // dflt_value
                row.get(5)?, // pk
            ))
        })
        .unwrap()
        .collect::<SqliteResult<Vec<_>>>()
        .unwrap();

    // Then: 应该有 9 个字段，包含所有必需字段，且 id 为主键
    assert_eq!(columns.len(), 9, "应该有9个字段");

    let field_names: Vec<String> = columns.iter().map(|c| c.1.clone()).collect();
    assert!(field_names.contains(&"id".to_string()));
    assert!(field_names.contains(&"title".to_string()));
    assert!(field_names.contains(&"content".to_string()));
    assert!(field_names.contains(&"created_at".to_string()));
    assert!(field_names.contains(&"updated_at".to_string()));
    assert!(field_names.contains(&"deleted".to_string()));
    assert!(field_names.contains(&"owner_type".to_string()));
    assert!(field_names.contains(&"pool_id".to_string()));
    assert!(field_names.contains(&"last_edit_peer".to_string()));

    let id_column = columns.iter().find(|c| c.1 == "id").unwrap();
    assert_eq!(id_column.5, 1, "id应该是主键");
}

/// 测试: 索引创建
#[test]
fn it_should_indexes_creation() {
    // Given: 一个包含 cards 表的内存数据库
    let conn = Connection::open_in_memory().unwrap();
    create_cards_table(&conn).unwrap();

    // When: 查询所有索引
    let mut stmt = conn
        .prepare("SELECT name FROM sqlite_master WHERE type='index'")
        .unwrap();
    let indexes: Vec<String> = stmt
        .query_map([], |row| row.get(0))
        .unwrap()
        .collect::<SqliteResult<Vec<_>>>()
        .unwrap();

    // Then: 应该存在 deleted 和 created_at 索引
    assert!(
        indexes.iter().any(|idx| idx.contains("deleted")),
        "应该有deleted索引"
    );
    assert!(
        indexes.iter().any(|idx| idx.contains("created_at")),
        "应该有created_at索引"
    );
}

// ==================== 2. SQLite优化参数测试 ====================

/// 测试: `SQLite优化参数配置`
///
/// 验收标准:
/// - WAL模式启用
/// - `cache_size设置正确`
/// - synchronous设置正确
#[test]
fn it_should_sqlite_optimization() {
    // Given: 一个内存数据库连接
    let conn = Connection::open_in_memory().unwrap();
    optimize_sqlite(&conn).unwrap();

    // When: 查询 PRAGMA 配置参数
    let journal_mode: String = conn
        .query_row("PRAGMA journal_mode", [], |row| row.get(0))
        .unwrap();
    let cache_size: i32 = conn
        .query_row("PRAGMA cache_size", [], |row| row.get(0))
        .unwrap();
    let synchronous: i32 = conn
        .query_row("PRAGMA synchronous", [], |row| row.get(0))
        .unwrap();

    // Then: 优化参数应该被正确设置
    assert_eq!(
        journal_mode.to_uppercase(),
        "MEMORY",
        "内存数据库应该使用MEMORY模式"
    );
    assert!(cache_size != 0, "cache_size应该被设置");
    assert!(synchronous >= 0, "synchronous应该被设置");
}

// ==================== 3. CRUD操作测试 ====================

/// 测试: 插入卡片
#[test]
fn it_should_insert_card() -> Result<(), CardMindError> {
    // Given: 一个测试数据库和卡片对象
    let conn = setup_test_db();
    let card = require_card(Card::new(
        generate_uuid_v7(),
        "测试标题".to_string(),
        "测试内容".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;

    // When: 插入卡片
    let result = insert_card(&conn, &card);

    // Then: 插入应该成功，且可以查询到记录
    assert!(result.is_ok(), "插入卡片应该成功");

    let count: i64 = conn
        .query_row("SELECT COUNT(*) FROM cards", [], |row| row.get(0))
        .unwrap();
    assert_eq!(count, 1, "应该有1条记录");
    Ok(())
}

/// 测试: 查询所有卡片
#[test]
fn it_should_select_all_cards() -> Result<(), CardMindError> {
    // Given: 一个测试数据库和两张卡片
    let conn = setup_test_db();
    let card1 = require_card(Card::new(
        generate_uuid_v7(),
        "标题1".to_string(),
        "内容1".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;
    let card2 = require_card(Card::new(
        generate_uuid_v7(),
        "标题2".to_string(),
        "内容2".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;
    insert_card(&conn, &card1)?;
    insert_card(&conn, &card2)?;

    // When: 查询所有卡片
    let cards = select_all_cards(&conn)?;

    // Then: 应该查询到 2 条记录
    assert_eq!(cards.len(), 2, "应该查询到2条记录");
    Ok(())
}

/// 测试: 按ID查询卡片
#[test]
fn it_should_select_card_by_id() -> Result<(), CardMindError> {
    // Given: 一个测试数据库和已插入的卡片
    let conn = setup_test_db();
    let card = require_card(Card::new(
        generate_uuid_v7(),
        "标题".to_string(),
        "内容".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;
    let card_id = card.id.clone();
    insert_card(&conn, &card)?;

    // When: 按 ID 查询卡片
    let result = select_card_by_id(&conn, &card_id);

    // Then: 应该能查询到卡片，且内容正确
    assert!(result.is_ok(), "应该能查询到卡片");

    let found_card = result.unwrap();
    assert_eq!(found_card.id, card_id);
    assert_eq!(found_card.title, "标题");
    Ok(())
}

/// 测试: 查询不存在的卡片
#[test]
fn it_should_select_nonexistent_card() {
    // Given: 一个测试数据库
    let conn = setup_test_db();

    // When: 查询不存在的卡片 ID
    let result = select_card_by_id(&conn, "nonexistent-id");

    // Then: 应该返回 CardNotFound 错误
    assert!(result.is_err(), "查询不存在的卡片应该返回错误");

    if let Err(CardMindError::CardNotFound(id)) = result {
        assert_eq!(id, "nonexistent-id");
    } else {
        panic!("应该返回CardNotFound错误");
    }
}

/// 测试: 更新卡片
#[test]
fn it_should_update_card() -> Result<(), CardMindError> {
    // Given: 一个测试数据库和已插入的卡片
    let conn = setup_test_db();
    let mut card = require_card(Card::new(
        generate_uuid_v7(),
        "旧标题".to_string(),
        "旧内容".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;
    insert_card(&conn, &card)?;

    // When: 更新卡片的标题和内容
    card.update(
        Some("新标题".to_string()),
        Some("新内容".to_string()),
        "12D3KooWUpdatedPeer".to_string(),
    )?;
    let result = update_card(&conn, &card);

    // Then: 更新应该成功，且数据已更新
    assert!(result.is_ok(), "更新卡片应该成功");

    let updated_card = select_card_by_id(&conn, &card.id)?;
    assert_eq!(updated_card.title, "新标题");
    assert_eq!(updated_card.content, "新内容");
    Ok(())
}

/// 测试: 软删除卡片
#[test]
fn it_should_soft_delete_card() -> Result<(), CardMindError> {
    // Given: 一个测试数据库和已插入的卡片
    let conn = setup_test_db();
    let mut card = require_card(Card::new(
        generate_uuid_v7(),
        "标题".to_string(),
        "内容".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;
    insert_card(&conn, &card)?;

    // When: 软删除卡片
    card.mark_deleted("12D3KooWDeletePeer".to_string())?;
    let result = update_card(&conn, &card);

    // Then: 软删除应该成功，且 deleted 标记为 true
    assert!(result.is_ok(), "软删除应该成功");

    let deleted_card = select_card_by_id(&conn, &card.id)?;
    assert!(deleted_card.deleted, "deleted应该为true");
    Ok(())
}

/// 测试: 硬删除卡片
#[test]
fn it_should_hard_delete_card() -> Result<(), CardMindError> {
    // Given: 一个测试数据库和已插入的卡片
    let conn = setup_test_db();
    let card = require_card(Card::new(
        generate_uuid_v7(),
        "标题".to_string(),
        "内容".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;
    let card_id = card.id.clone();
    insert_card(&conn, &card)?;

    // When: 硬删除卡片
    let result = delete_card(&conn, &card_id);

    // Then: 硬删除应该成功，且不能再查询到该卡片
    assert!(result.is_ok(), "硬删除应该成功");

    let result = select_card_by_id(&conn, &card_id);
    assert!(result.is_err(), "删除后不应该能查询到卡片");
    Ok(())
}

/// 测试: 查询时排除已删除的卡片
#[test]
fn it_should_select_excludes_deleted_cards() -> Result<(), CardMindError> {
    // Given: 一个测试数据库和两张卡片
    let conn = setup_test_db();
    let mut card1 = require_card(Card::new(
        generate_uuid_v7(),
        "标题1".to_string(),
        "内容1".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;
    let card2 = require_card(Card::new(
        generate_uuid_v7(),
        "标题2".to_string(),
        "内容2".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    ))?;

    // When: 软删除其中一张卡片，然后查询所有未删除的卡片
    insert_card(&conn, &card1)?;
    insert_card(&conn, &card2)?;

    card1.mark_deleted("12D3KooWDeletePeer".to_string())?;
    update_card(&conn, &card1)?;

    let cards = select_active_cards(&conn)?;

    // Then: 应该只返回未删除的卡片
    assert_eq!(cards.len(), 1, "应该只返回1个未删除的卡片");
    assert_eq!(cards[0].id, card2.id);
    Ok(())
}

// ==================== 辅助函数 ====================

/// 创建测试用的数据库（包含表和优化）
fn setup_test_db() -> Connection {
    let conn = Connection::open_in_memory().unwrap();
    create_cards_table(&conn).unwrap();
    optimize_sqlite(&conn).unwrap();
    conn
}

/// 创建cards表
fn create_cards_table(conn: &Connection) -> Result<(), CardMindError> {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS cards (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0,
            owner_type TEXT NOT NULL,
            pool_id TEXT,
            last_edit_peer TEXT NOT NULL
        )",
        [],
    )?;

    // 创建索引
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted)",
        [],
    )?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_cards_created_at ON cards(created_at DESC)",
        [],
    )?;

    Ok(())
}

/// `配置SQLite优化参数`
fn optimize_sqlite(conn: &Connection) -> Result<(), CardMindError> {
    // 使用pragma_update来设置PRAGMA值（不期望返回结果）
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "cache_size", -10000)?;
    conn.pragma_update(None, "synchronous", "NORMAL")?;
    conn.pragma_update(None, "foreign_keys", true)?;

    Ok(())
}

/// `插入卡片到SQLite`
fn insert_card(conn: &Connection, card: &Card) -> Result<(), CardMindError> {
    conn.execute(
        "INSERT INTO cards (id, title, content, created_at, updated_at, deleted, owner_type, pool_id, last_edit_peer)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        rusqlite::params![
            &card.id,
            &card.title,
            &card.content,
            card.created_at,
            card.updated_at,
            card.deleted,
            card.owner_type.as_str(),
            &card.pool_id,
            &card.last_edit_peer,
        ],
    )?;
    Ok(())
}

/// 查询所有卡片（包括已删除）
fn select_all_cards(conn: &Connection) -> Result<Vec<Card>, CardMindError> {
    let mut stmt = conn.prepare(
        "SELECT id, title, content, created_at, updated_at, deleted, owner_type, pool_id, last_edit_peer FROM cards",
    )?;

    let cards = stmt
        .query_map([], |row| {
            Ok(Card {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
                deleted: row.get(5)?,
                owner_type: parse_owner_type(row.get::<_, String>(6)?)?,
                pool_id: row.get(7)?,
                last_edit_peer: row.get(8)?,
            })
        })?
        .collect::<SqliteResult<Vec<_>>>()?;

    Ok(cards)
}

/// 查询所有未删除的卡片
fn select_active_cards(conn: &Connection) -> Result<Vec<Card>, CardMindError> {
    let mut stmt = conn.prepare(
        "SELECT id, title, content, created_at, updated_at, deleted, owner_type, pool_id, last_edit_peer
         FROM cards
         WHERE deleted = 0
         ORDER BY created_at DESC",
    )?;

    let cards = stmt
        .query_map([], |row| {
            Ok(Card {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
                deleted: row.get(5)?,
                owner_type: parse_owner_type(row.get::<_, String>(6)?)?,
                pool_id: row.get(7)?,
                last_edit_peer: row.get(8)?,
            })
        })?
        .collect::<SqliteResult<Vec<_>>>()?;

    Ok(cards)
}

/// 按ID查询卡片
fn select_card_by_id(conn: &Connection, id: &str) -> Result<Card, CardMindError> {
    let mut stmt = conn.prepare(
        "SELECT id, title, content, created_at, updated_at, deleted, owner_type, pool_id, last_edit_peer
         FROM cards
         WHERE id = ?1",
    )?;

    let card = stmt.query_row([id], |row| {
        Ok(Card {
            id: row.get(0)?,
            title: row.get(1)?,
            content: row.get(2)?,
            created_at: row.get(3)?,
            updated_at: row.get(4)?,
            deleted: row.get(5)?,
            owner_type: parse_owner_type(row.get::<_, String>(6)?)?,
            pool_id: row.get(7)?,
            last_edit_peer: row.get(8)?,
        })
    });

    match card {
        Ok(c) => Ok(c),
        Err(rusqlite::Error::QueryReturnedNoRows) => {
            Err(CardMindError::CardNotFound(id.to_string()))
        }
        Err(e) => Err(CardMindError::DatabaseError(e.to_string())),
    }
}

/// 更新卡片
fn update_card(conn: &Connection, card: &Card) -> Result<(), CardMindError> {
    let rows_affected = conn.execute(
        "UPDATE cards
         SET title = ?1, content = ?2, updated_at = ?3, deleted = ?4, owner_type = ?5, pool_id = ?6, last_edit_peer = ?7
         WHERE id = ?8",
        rusqlite::params![
            &card.title,
            &card.content,
            card.updated_at,
            card.deleted,
            card.owner_type.as_str(),
            &card.pool_id,
            &card.last_edit_peer,
            &card.id,
        ],
    )?;

    if rows_affected == 0 {
        return Err(CardMindError::CardNotFound(card.id.clone()));
    }

    Ok(())
}

/// 硬删除卡片
fn delete_card(conn: &Connection, id: &str) -> Result<(), CardMindError> {
    let rows_affected = conn.execute("DELETE FROM cards WHERE id = ?1", [id])?;

    if rows_affected == 0 {
        return Err(CardMindError::CardNotFound(id.to_string()));
    }

    Ok(())
}

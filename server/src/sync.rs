use axum::{
    extract::State,
    http::StatusCode,
    Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use crate::database::DatabasePool;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct SyncedCard {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sync_version: i64,
    pub device_id: String,
}

#[derive(Debug, Deserialize)]
pub struct SyncRequest {
    pub last_sync: DateTime<Utc>,
    pub changes: Vec<SyncedCard>,
}

#[derive(Debug, Serialize)]
pub struct SyncResponse {
    pub server_time: DateTime<Utc>,
    pub changes: Vec<SyncedCard>,
    pub conflicts: Vec<SyncedCard>,
}

pub async fn sync_cards(
    State(pool): State<DatabasePool>,
    Json(request): Json<SyncRequest>,
) -> Result<Json<SyncResponse>, (StatusCode, String)> {
    let mut conflicts = Vec::new();

    // 1. 获取服务器上次同步后的更改
    let query = r#"
        SELECT id, title, content, created_at, updated_at, sync_version, device_id
        FROM cards
        WHERE updated_at > $1
    "#;

    let server_updates = match (pool.get_sqlite(), pool.get_postgres()) {
        (Some(sqlite), _) => {
            sqlx::query_as::<_, SyncedCard>(query)
                .bind(request.last_sync)
                .fetch_all(sqlite)
                .await
        }
        (_, Some(postgres)) => {
            sqlx::query_as::<_, SyncedCard>(query)
                .bind(request.last_sync)
                .fetch_all(postgres)
                .await
        }
        _ => return Err((StatusCode::INTERNAL_SERVER_ERROR, "No database connection available".to_string())),
    }.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;

    // 2. 处理客户端的更改
    for client_card in request.changes {
        // 检查是否存在冲突
        let query = r#"
            SELECT id, title, content, created_at, updated_at, sync_version, device_id
            FROM cards
            WHERE id = $1
        "#;

        let existing = match (pool.get_sqlite(), pool.get_postgres()) {
            (Some(sqlite), _) => {
                sqlx::query_as::<_, SyncedCard>(query)
                    .bind(&client_card.id)
                    .fetch_optional(sqlite)
                    .await
            }
            (_, Some(postgres)) => {
                sqlx::query_as::<_, SyncedCard>(query)
                    .bind(&client_card.id)
                    .fetch_optional(postgres)
                    .await
            }
            _ => return Err((StatusCode::INTERNAL_SERVER_ERROR, "No database connection available".to_string())),
        }.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;

        match existing {
            Some(server_card) => {
                if server_card.sync_version > client_card.sync_version {
                    // 存在冲突
                    conflicts.push(server_card);
                } else {
                    // 更新服务器版本
                    let query = r#"
                        UPDATE cards
                        SET title = $1, content = $2, updated_at = $3, sync_version = $4, device_id = $5
                        WHERE id = $6
                    "#;

                    match (pool.get_sqlite(), pool.get_postgres()) {
                        (Some(sqlite), _) => {
                            sqlx::query(query)
                                .bind(&client_card.title)
                                .bind(&client_card.content)
                                .bind(client_card.updated_at)
                                .bind(client_card.sync_version + 1)
                                .bind(&client_card.device_id)
                                .bind(&client_card.id)
                                .execute(sqlite)
                                .await
                                .map(|_| ())
                        }
                        (_, Some(postgres)) => {
                            sqlx::query(query)
                                .bind(&client_card.title)
                                .bind(&client_card.content)
                                .bind(client_card.updated_at)
                                .bind(client_card.sync_version + 1)
                                .bind(&client_card.device_id)
                                .bind(&client_card.id)
                                .execute(postgres)
                                .await
                                .map(|_| ())
                        }
                        _ => return Err((StatusCode::INTERNAL_SERVER_ERROR, "No database connection available".to_string())),
                    }.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
                }
            }
            None => {
                // 新卡片，直接插入
                let query = r#"
                    INSERT INTO cards (id, title, content, created_at, updated_at, sync_version, device_id)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                "#;

                match (pool.get_sqlite(), pool.get_postgres()) {
                    (Some(sqlite), _) => {
                        sqlx::query(query)
                            .bind(&client_card.id)
                            .bind(&client_card.title)
                            .bind(&client_card.content)
                            .bind(client_card.created_at)
                            .bind(client_card.updated_at)
                            .bind(client_card.sync_version)
                            .bind(&client_card.device_id)
                            .execute(sqlite)
                            .await
                            .map(|_| ())
                    }
                    (_, Some(postgres)) => {
                        sqlx::query(query)
                            .bind(&client_card.id)
                            .bind(&client_card.title)
                            .bind(&client_card.content)
                            .bind(client_card.created_at)
                            .bind(client_card.updated_at)
                            .bind(client_card.sync_version)
                            .bind(&client_card.device_id)
                            .execute(postgres)
                            .await
                            .map(|_| ())
                    }
                    _ => return Err((StatusCode::INTERNAL_SERVER_ERROR, "No database connection available".to_string())),
                }.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
            }
        }
    }

    Ok(Json(SyncResponse {
        server_time: Utc::now(),
        changes: server_updates,
        conflicts,
    }))
}

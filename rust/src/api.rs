// input: 来自 FRB/上层的应用配置、网络句柄与字符串参数，以及 store/network 操作返回的领域错误。
// output: 应用配置结果、网络初始化与关闭结果、后端用例 DTO、同步状态 DTO 与统一 ApiError 映射。
// pos: Rust API 门面模块，负责应用级运行配置、网络句柄生命周期管理、后端用例编排与跨层错误转换。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件承接对外 API、组装稳定 DTO 并做错误码映射。
use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use crate::net::endpoint::{build_endpoint, PoolEndpoint};
use crate::net::pool_network::PoolNetwork;
use crate::store::card_store::CardNoteRepository;
use crate::store::pool_store::PoolStore;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use uuid::Uuid;

static APP_CONFIG_DIR: OnceLock<Mutex<Option<String>>> = OnceLock::new();
static POOL_NETWORK_SEQ: AtomicU64 = AtomicU64::new(1);
static POOL_NETWORKS: OnceLock<Mutex<HashMap<u64, PoolNetwork>>> = OnceLock::new();

fn pool_network_map() -> &'static Mutex<HashMap<u64, PoolNetwork>> {
    POOL_NETWORKS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn app_config_dir() -> &'static Mutex<Option<String>> {
    APP_CONFIG_DIR.get_or_init(|| Mutex::new(None))
}

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::InvalidArgument(msg) => ApiError::new(ApiErrorCode::InvalidArgument, &msg),
        CardMindError::NotFound(msg) => ApiError::new(ApiErrorCode::NotFound, &msg),
        CardMindError::ProjectionNotConverged { retry_action, .. } => {
            ApiError::new(ApiErrorCode::ProjectionNotConverged, &retry_action)
        }
        CardMindError::NotImplemented(msg) => ApiError::new(ApiErrorCode::NotImplemented, &msg),
        CardMindError::NotMember(msg) => ApiError::new(ApiErrorCode::NotMember, &msg),
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        CardMindError::Sqlite(msg) => ApiError::new(ApiErrorCode::SqliteError, &msg),
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolDto {
    pub id: String,
    pub name: String,
    pub is_dissolved: bool,
    pub current_user_role: String,
    pub member_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolMemberDto {
    pub endpoint_id: String,
    pub nickname: String,
    pub os: String,
    pub role: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolDetailDto {
    pub id: String,
    pub name: String,
    pub is_dissolved: bool,
    pub current_user_role: String,
    pub member_count: usize,
    pub note_ids: Vec<String>,
    pub members: Vec<PoolMemberDto>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CardNoteDto {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncStatusDto {
    pub state: String,
    pub write_state: String,
    pub projection_state: String,
    pub sync_state: String,
    pub code: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResultDto {
    pub state: String,
    pub write_state: String,
    pub projection_state: String,
    pub sync_state: String,
    pub code: Option<String>,
}

fn projection_state(base_path: &str) -> Result<(String, Option<String>), ApiError> {
    let paths = crate::store::path_resolver::DataPaths::new(base_path).map_err(map_err)?;
    let sqlite =
        crate::store::sqlite_store::SqliteStore::new(&paths.sqlite_path).map_err(map_err)?;
    if sqlite.has_projection_failures().map_err(map_err)? {
        Ok((
            "projection_pending".to_string(),
            Some(ApiErrorCode::ProjectionNotConverged.as_str().to_string()),
        ))
    } else {
        Ok(("projection_ready".to_string(), None))
    }
}

fn combine_sync_status(
    base_path: &str,
    sync_state: &str,
    sync_code: Option<String>,
) -> Result<SyncStatusDto, ApiError> {
    let (projection_state, projection_code) = projection_state(base_path)?;
    let state = if sync_state == "sync_failed" || projection_state == "projection_pending" {
        "degraded".to_string()
    } else {
        sync_state.to_string()
    };

    Ok(SyncStatusDto {
        state,
        write_state: "write_saved".to_string(),
        projection_state,
        sync_state: sync_state.to_string(),
        code: sync_code.or(projection_code),
    })
}

fn combine_sync_result(
    base_path: &str,
    sync_state: &str,
    sync_code: Option<String>,
) -> Result<SyncResultDto, ApiError> {
    let (projection_state, projection_code) = projection_state(base_path)?;
    let state = if sync_state == "sync_failed" || projection_state == "projection_pending" {
        "degraded".to_string()
    } else {
        "ok".to_string()
    };

    Ok(SyncResultDto {
        state,
        write_state: "write_saved".to_string(),
        projection_state,
        sync_state: sync_state.to_string(),
        code: sync_code.or(projection_code),
    })
}

fn parse_uuid(raw: &str, field: &str) -> Result<Uuid, ApiError> {
    Uuid::parse_str(raw)
        .map_err(|_| ApiError::new(ApiErrorCode::InvalidArgument, &format!("invalid {field}")))
}

fn configured_app_data_dir() -> Result<String, ApiError> {
    let app_config = app_config_dir()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "app config lock poisoned"))?;
    app_config.clone().ok_or_else(|| {
        ApiError::new(
            ApiErrorCode::AppConfigNotInitialized,
            "app config not initialized",
        )
    })
}

fn with_configured_card_store<T>(
    f: impl FnOnce(&CardNoteRepository) -> Result<T, ApiError>,
) -> Result<T, ApiError> {
    let app_data_dir = configured_app_data_dir()?;
    let card_repository = CardNoteRepository::new(&app_data_dir).map_err(map_err)?;
    f(&card_repository)
}

fn with_configured_pool_store<T>(
    f: impl FnOnce(&PoolStore) -> Result<T, ApiError>,
) -> Result<T, ApiError> {
    let app_data_dir = configured_app_data_dir()?;
    let pool_store = PoolStore::new(&app_data_dir).map_err(map_err)?;
    f(&pool_store)
}

fn list_all_card_ids(card_repository: &CardNoteRepository) -> Result<Vec<Uuid>, ApiError> {
    let cards = card_repository.list_cards(10_000, 0).map_err(map_err)?;
    Ok(cards.into_iter().map(|card| card.id).collect())
}

fn parse_pool_id(pool_id: &str) -> Result<Uuid, ApiError> {
    parse_uuid(pool_id, "pool_id")
}

fn parse_card_id(card_id: &str) -> Result<Uuid, ApiError> {
    parse_uuid(card_id, "card_id")
}

fn pool_name(pool: &Pool) -> String {
    pool.members
        .first()
        .map(|member| format!("{}'s pool", member.nickname))
        .unwrap_or_else(|| "pool".to_string())
}

fn member_role(member: &PoolMember) -> String {
    if member.is_admin {
        "admin".to_string()
    } else {
        "member".to_string()
    }
}

fn current_member_for_endpoint<'a>(pool: &'a Pool, endpoint_id: &str) -> Option<&'a PoolMember> {
    pool.members
        .iter()
        .find(|member| member.endpoint_id == endpoint_id)
}

fn current_user_role_for_endpoint(pool: &Pool, endpoint_id: &str) -> String {
    current_member_for_endpoint(pool, endpoint_id)
        .map(member_role)
        .unwrap_or_else(|| "member".to_string())
}

fn fallback_endpoint_id(pool: &Pool) -> &str {
    pool.members
        .first()
        .map(|member| member.endpoint_id.as_str())
        .unwrap_or("")
}

fn to_pool_dto(pool: &Pool, endpoint_id: &str) -> PoolDto {
    PoolDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: false,
        current_user_role: current_user_role_for_endpoint(pool, endpoint_id),
        member_count: pool.members.len(),
    }
}

fn to_pool_detail_dto(pool: &Pool, endpoint_id: &str) -> PoolDetailDto {
    PoolDetailDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: false,
        current_user_role: current_user_role_for_endpoint(pool, endpoint_id),
        member_count: pool.members.len(),
        note_ids: pool.card_ids.iter().map(Uuid::to_string).collect(),
        members: pool
            .members
            .iter()
            .map(|member| PoolMemberDto {
                endpoint_id: member.endpoint_id.clone(),
                nickname: member.nickname.clone(),
                os: member.os.clone(),
                role: member_role(member),
            })
            .collect(),
    }
}

fn to_card_note_dto(card: &Card) -> CardNoteDto {
    CardNoteDto {
        id: card.id.to_string(),
        title: card.title.clone(),
        content: card.content.clone(),
        created_at: card.created_at,
        updated_at: card.updated_at,
        deleted: card.deleted,
    }
}

/// 初始化应用级配置
pub fn init_app_config(app_data_dir: String) -> Result<(), ApiError> {
    let mut config = app_config_dir()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "app config lock poisoned"))?;
    match config.as_ref() {
        None => {
            CardNoteRepository::new(&app_data_dir).map_err(map_err)?;
            *config = Some(app_data_dir);
            Ok(())
        }
        Some(current) if current == &app_data_dir => Ok(()),
        Some(_) => Err(ApiError::new(
            ApiErrorCode::AppConfigConflict,
            "app config already initialized with different directory",
        )),
    }
}

#[doc(hidden)]
pub fn reset_app_config_for_tests() -> Result<(), ApiError> {
    let mut config = app_config_dir()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "app config lock poisoned"))?;
    *config = None;
    Ok(())
}

pub fn create_pool(endpoint_id: String, nickname: String, os: String) -> Result<PoolDto, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pool = pool_store
            .create_pool(&endpoint_id, &nickname, &os)
            .map_err(map_err)?;
        Ok(to_pool_dto(&pool, &endpoint_id))
    })
}

pub fn join_pool(
    pool_id: String,
    endpoint_id: String,
    nickname: String,
    os: String,
) -> Result<PoolDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let pool_id = parse_pool_id(&pool_id)?;
        let local_card_ids = list_all_card_ids(card_repository)?;
        let base_path = card_repository.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        let pool = pool_store.get_pool(&pool_id).map_err(map_err)?;
        let updated = pool_store
            .join_pool(
                &pool,
                PoolMember {
                    endpoint_id: endpoint_id.clone(),
                    nickname,
                    os,
                    is_admin: false,
                },
                local_card_ids,
            )
            .map_err(map_err)?;
        Ok(to_pool_dto(&updated, &endpoint_id))
    })
}

pub fn join_by_code(
    code: String,
    endpoint_id: String,
    nickname: String,
    os: String,
) -> Result<PoolDto, ApiError> {
    if code == "timeout" {
        return Err(ApiError::new(
            ApiErrorCode::RequestTimeout,
            "join request timed out",
        ));
    }

    with_configured_card_store(|card_repository| {
        let local_card_ids = list_all_card_ids(card_repository)?;
        let base_path = card_repository.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        let updated = pool_store
            .join_by_code(
                &code,
                PoolMember {
                    endpoint_id: endpoint_id.clone(),
                    nickname,
                    os,
                    is_admin: false,
                },
                local_card_ids,
            )
            .map_err(|err| match err {
                CardMindError::InvalidArgument(_) => {
                    ApiError::new(ApiErrorCode::InvalidPoolHash, "invalid join code")
                }
                CardMindError::NotFound(_) => {
                    ApiError::new(ApiErrorCode::PoolNotFound, "pool not found")
                }
                other => map_err(other),
            })?;
        Ok(to_pool_dto(&updated, &endpoint_id))
    })
}

pub fn list_pools() -> Result<Vec<PoolDto>, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pools = pool_store
            .get_any_pool()
            .map(|pool| vec![pool])
            .or_else(|err| match err {
                CardMindError::NotFound(_) => Ok(Vec::new()),
                other => Err(other),
            })
            .map_err(map_err)?;
        Ok(pools
            .iter()
            .map(|pool| to_pool_dto(pool, fallback_endpoint_id(pool)))
            .collect())
    })
}

pub fn get_pool_detail(pool_id: String) -> Result<PoolDetailDto, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pool_id = parse_pool_id(&pool_id)?;
        let pool = pool_store.get_pool(&pool_id).map_err(map_err)?;
        Ok(to_pool_detail_dto(&pool, fallback_endpoint_id(&pool)))
    })
}

pub fn get_joined_pool_view(endpoint_id: String) -> Result<PoolDetailDto, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pool = pool_store.get_any_pool().map_err(map_err)?;
        Ok(to_pool_detail_dto(&pool, &endpoint_id))
    })
}

pub fn create_card_note(title: String, content: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card = card_repository
            .create_card(&title, &content)
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn create_card_note_in_pool(
    pool_id: String,
    title: String,
    content: String,
) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let pool_id = parse_pool_id(&pool_id)?;
        let card = card_repository
            .create_card(&title, &content)
            .map_err(map_err)?;
        let base_path = card_repository.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        pool_store
            .attach_note_references(&pool_id, vec![card.id])
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn update_card_note(
    card_id: String,
    title: String,
    content: String,
) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        let card = card_repository
            .update_card(&card_id, &title, &content)
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn delete_card_note(card_id: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        card_repository.delete_card(&card_id).map_err(map_err)?;
        let card = card_repository.get_card(&card_id).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn restore_card_note(card_id: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        card_repository.restore_card(&card_id).map_err(map_err)?;
        let card = card_repository.get_card(&card_id).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn list_card_notes() -> Result<Vec<CardNoteDto>, ApiError> {
    with_configured_card_store(|card_repository| {
        let cards = card_repository.list_cards(10_000, 0).map_err(map_err)?;
        Ok(cards.iter().map(to_card_note_dto).collect())
    })
}

pub fn query_card_notes(
    query: String,
    include_deleted: bool,
) -> Result<Vec<CardNoteDto>, ApiError> {
    with_configured_card_store(|card_repository| {
        let cards = card_repository
            .query_cards(&query, include_deleted, 10_000, 0)
            .map_err(map_err)?;
        Ok(cards.iter().map(to_card_note_dto).collect())
    })
}

pub fn get_card_note_detail(card_id: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        let card = card_repository.get_card(&card_id).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 初始化 PoolNetwork
pub fn init_pool_network(base_path: String) -> Result<u64, ApiError> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| ApiError::new(ApiErrorCode::Internal, &e.to_string()))?;
    let endpoint = runtime.block_on(build_endpoint()).map_err(map_err)?;
    let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
    let card_repository = CardNoteRepository::new(&base_path).map_err(map_err)?;
    let network = PoolNetwork::new(PoolEndpoint::new(endpoint), pool_store, card_repository);
    let network_id = POOL_NETWORK_SEQ.fetch_add(1, Ordering::SeqCst);
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    map.insert(network_id, network);
    Ok(network_id)
}

/// 关闭 PoolNetwork
pub fn close_pool_network(network_id: u64) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    if map.remove(&network_id).is_none() {
        return Err(ApiError::new(
            ApiErrorCode::NotFound,
            "pool network not found",
        ));
    }
    Ok(())
}

pub fn sync_status(network_id: u64) -> Result<SyncStatusDto, ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    combine_sync_status(
        network.base_path(),
        network.sync_state(),
        network.last_sync_error_code().map(|code| code.to_string()),
    )
}

pub fn sync_connect(network_id: u64, target: String) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_connect(target).map_err(map_err)
}

pub fn sync_disconnect(network_id: u64) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_disconnect();
    Ok(())
}

pub fn sync_join_pool(network_id: u64, pool_id: String) -> Result<(), ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_join_pool(&pool_id).map_err(map_err)
}

pub fn sync_push(network_id: u64) -> Result<SyncResultDto, ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    let sync_code = match network.sync_push() {
        Ok(()) => None,
        Err(CardMindError::InvalidArgument(msg)) if msg == "sync not connected" => {
            Some(ApiErrorCode::RequestTimeout.as_str().to_string())
        }
        Err(other) => return Err(map_err(other)),
    };
    combine_sync_result(network.base_path(), network.sync_state(), sync_code)
}

pub fn sync_pull(network_id: u64) -> Result<SyncResultDto, ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    let sync_code = match network.sync_pull() {
        Ok(()) => None,
        Err(CardMindError::InvalidArgument(msg)) if msg == "sync not connected" => {
            Some(ApiErrorCode::RequestTimeout.as_str().to_string())
        }
        Err(other) => return Err(map_err(other)),
    };
    combine_sync_result(network.base_path(), network.sync_state(), sync_code)
}

// input: CardMind 统一错误类型与存储句柄
// output: 对外 API 错误与句柄管理
// pos: FRB API 入口（修改本文件需同步更新文件头与所属 DIR.md）
use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::error::CardMindError;
use crate::net::endpoint::{build_endpoint, PoolEndpoint};
use crate::net::pool_network::PoolNetwork;
use crate::store::card_store::CardStore;
use crate::store::pool_store::PoolStore;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

static CARD_STORE_SEQ: AtomicU64 = AtomicU64::new(1);
static CARD_STORES: OnceLock<Mutex<HashMap<u64, CardStore>>> = OnceLock::new();
static POOL_NETWORK_SEQ: AtomicU64 = AtomicU64::new(1);
static POOL_NETWORKS: OnceLock<Mutex<HashMap<u64, PoolNetwork>>> = OnceLock::new();

fn card_store_map() -> &'static Mutex<HashMap<u64, CardStore>> {
    CARD_STORES.get_or_init(|| Mutex::new(HashMap::new()))
}

fn pool_network_map() -> &'static Mutex<HashMap<u64, PoolNetwork>> {
    POOL_NETWORKS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::InvalidArgument(msg) => ApiError::new(ApiErrorCode::InvalidArgument, &msg),
        CardMindError::NotFound(msg) => ApiError::new(ApiErrorCode::NotFound, &msg),
        CardMindError::NotImplemented(msg) => ApiError::new(ApiErrorCode::NotImplemented, &msg),
        CardMindError::NotMember(msg) => ApiError::new(ApiErrorCode::NotMember, &msg),
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        CardMindError::Sqlite(msg) => ApiError::new(ApiErrorCode::SqliteError, &msg),
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

/// 初始化 CardStore
pub fn init_card_store(base_path: String) -> Result<u64, ApiError> {
    let store = CardStore::new(&base_path).map_err(map_err)?;
    let store_id = CARD_STORE_SEQ.fetch_add(1, Ordering::SeqCst);
    let mut map = card_store_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    map.insert(store_id, store);
    Ok(store_id)
}

/// 关闭 CardStore
pub fn close_card_store(store_id: u64) -> Result<(), ApiError> {
    let mut map = card_store_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    if map.remove(&store_id).is_none() {
        return Err(ApiError::new(ApiErrorCode::NotFound, "card store not found"));
    }
    Ok(())
}

/// 初始化 PoolNetwork
pub fn init_pool_network(base_path: String) -> Result<u64, ApiError> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| ApiError::new(ApiErrorCode::Internal, &e.to_string()))?;
    let endpoint = runtime.block_on(build_endpoint()).map_err(map_err)?;
    let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
    let card_store = CardStore::new(&base_path).map_err(map_err)?;
    let network = PoolNetwork::new(PoolEndpoint::new(endpoint), pool_store, card_store);
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

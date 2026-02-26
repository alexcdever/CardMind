// input: 
// output: 
// pos: 
use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::error::CardMindError;
use crate::store::card_store::CardStore;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

static CARD_STORE_SEQ: AtomicU64 = AtomicU64::new(1);
static CARD_STORES: OnceLock<Mutex<HashMap<u64, CardStore>>> = OnceLock::new();

fn card_store_map() -> &'static Mutex<HashMap<u64, CardStore>> {
    CARD_STORES.get_or_init(|| Mutex::new(HashMap::new()))
}

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::InvalidArgument(msg) => ApiError::new(ApiErrorCode::InvalidArgument, &msg),
        CardMindError::NotFound(msg) => ApiError::new(ApiErrorCode::NotFound, &msg),
        CardMindError::NotImplemented(msg) => ApiError::new(ApiErrorCode::NotImplemented, &msg),
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

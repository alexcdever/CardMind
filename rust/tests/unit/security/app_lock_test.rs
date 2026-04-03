use cardmind_rust::security::app_lock::{AppLock, AppLockError, ResetToken};
use cardmind_rust::security::app_lock::{AppLockState, AppLockStorage};
use std::sync::{Arc, Mutex};

#[derive(Clone, Default)]
struct RecordingStorage {
    inner: Arc<Mutex<RecordingStorageInner>>,
}

#[derive(Default, Clone)]
struct RecordingStorageInner {
    load_calls: usize,
    store_calls: usize,
    clear_calls: usize,
    state: Option<AppLockState>,
}

impl RecordingStorage {
    fn new() -> Self {
        Self::default()
    }

    fn load_calls(&self) -> usize {
        self.inner.lock().unwrap().load_calls
    }

    fn store_calls(&self) -> usize {
        self.inner.lock().unwrap().store_calls
    }

    fn clear_calls(&self) -> usize {
        self.inner.lock().unwrap().clear_calls
    }
}

impl AppLockStorage for RecordingStorage {
    fn load_state(&self) -> Option<AppLockState> {
        let mut inner = self.inner.lock().unwrap();
        inner.load_calls += 1;
        inner.state.clone()
    }

    fn store_state(&self, state: &AppLockState) {
        let mut inner = self.inner.lock().unwrap();
        inner.store_calls += 1;
        inner.state = Some(state.clone());
    }

    fn clear_state(&self) {
        let mut inner = self.inner.lock().unwrap();
        inner.clear_calls += 1;
        inner.state = None;
    }
}

fn lock_with_storage() -> (AppLock, RecordingStorage) {
    let storage = RecordingStorage::new();
    let lock = AppLock::with_storage(Box::new(storage.clone()));
    (lock, storage)
}

#[test]
fn new_state_unset() {
    let (lock, storage) = lock_with_storage();
    assert_eq!(storage.load_calls(), 1);
    assert!(!lock.state().is_configured());
    assert!(!lock.state().is_locked());
    assert_eq!(lock.state().failed_attempts(), 0);
}

#[test]
fn set_pin_configures_state_and_persists() {
    let (mut lock, storage) = lock_with_storage();
    lock.set_pin("1234", true).unwrap();
    assert!(lock.state().is_configured());
    assert!(lock.state().allow_biometric());
    assert_eq!(storage.store_calls(), 1);
}

#[test]
fn verify_pin_success_and_reset_failures() {
    let (mut lock, storage) = lock_with_storage();
    lock.set_pin("1234", false).unwrap();
    lock.verify_pin("0000").unwrap_err();
    assert_eq!(storage.store_calls(), 2);
    lock.verify_pin("1234").unwrap();
    assert_eq!(lock.state().failed_attempts(), 0);
    assert!(!lock.state().is_locked());
}

#[test]
fn verify_pin_locks_on_threshold() {
    let (mut lock, storage) = lock_with_storage();
    lock.set_pin("1234", false).unwrap();
    for _ in 0..5 {
        assert_eq!(lock.verify_pin("0000"), Err(AppLockError::InvalidPin));
    }
    assert!(matches!(lock.verify_pin("1234"), Err(AppLockError::Locked)));
    assert_eq!(storage.store_calls(), 6);
}

#[test]
fn biometric_success_resets_lock_and_persists() {
    let (mut lock, storage) = lock_with_storage();
    lock.set_pin("1234", false).unwrap();
    for _ in 0..5 {
        lock.verify_pin("0000").unwrap_err();
    }
    assert!(lock.state().is_locked());
    lock.mark_biometric_success().unwrap();
    assert!(!lock.state().is_locked());
    assert_eq!(lock.state().failed_attempts(), 0);
    assert!(storage.store_calls() >= 6);
}

#[test]
fn reset_with_token_clears_state_and_storage() {
    let (mut lock, storage) = lock_with_storage();
    lock.set_pin("1234", true).unwrap();
    lock.verify_pin("0000").unwrap_err();
    lock.reset_with_token(&ResetToken::privileged()).unwrap();
    assert!(!lock.state().is_configured());
    assert_eq!(lock.state().failed_attempts(), 0);
    assert_eq!(storage.clear_calls(), 1);
}

#[test]
fn reset_without_token_fails() {
    let (mut lock, storage) = lock_with_storage();
    lock.set_pin("1234", false).unwrap();
    assert_eq!(
        lock.reset_with_token(&ResetToken::unprivileged()),
        Err(AppLockError::InvalidResetToken)
    );
    assert_eq!(storage.clear_calls(), 0);
}

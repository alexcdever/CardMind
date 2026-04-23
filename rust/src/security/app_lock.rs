use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString, rand_core::OsRng},
};
use std::sync::{Arc, Mutex};

const MAX_FAILED_ATTEMPTS: u32 = 5;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AppLockState {
    hashed_pin: Option<String>,
    allow_biometric: bool,
    failed_attempts: u32,
    locked: bool,
}

impl Default for AppLockState {
    fn default() -> Self {
        Self::new()
    }
}

impl AppLockState {
    pub fn new() -> Self {
        Self {
            hashed_pin: None,
            allow_biometric: false,
            failed_attempts: 0,
            locked: false,
        }
    }

    pub fn is_configured(&self) -> bool {
        self.hashed_pin.is_some()
    }

    pub fn is_locked(&self) -> bool {
        self.locked
    }

    pub fn failed_attempts(&self) -> u32 {
        self.failed_attempts
    }

    pub fn allow_biometric(&self) -> bool {
        self.allow_biometric
    }
}

pub trait AppLockStorage: Send + Sync {
    fn load_state(&self) -> Option<AppLockState>;
    fn store_state(&self, state: &AppLockState);
    fn clear_state(&self);
}

#[derive(Clone, Default)]
pub struct InMemoryAppLockStorage {
    state: Arc<Mutex<Option<AppLockState>>>,
}

impl AppLockStorage for InMemoryAppLockStorage {
    fn load_state(&self) -> Option<AppLockState> {
        self.state.lock().unwrap().clone()
    }

    fn store_state(&self, state: &AppLockState) {
        *self.state.lock().unwrap() = Some(state.clone());
    }

    fn clear_state(&self) {
        *self.state.lock().unwrap() = None;
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum AppLockError {
    #[error("app lock is not configured")]
    NotConfigured,
    #[error("app lock is currently locked")]
    Locked,
    #[error("provided PIN is invalid")]
    InvalidPin,
    #[error("reset token is invalid")]
    InvalidResetToken,
}

#[derive(Debug, Clone)]
pub struct ResetToken(bool);

impl ResetToken {
    pub fn privileged() -> Self {
        Self(true)
    }

    pub fn unprivileged() -> Self {
        Self(false)
    }

    fn is_valid(&self) -> bool {
        self.0
    }
}

pub struct AppLock {
    state: AppLockState,
    storage: Box<dyn AppLockStorage>,
}

impl Default for AppLock {
    fn default() -> Self {
        Self::new()
    }
}

impl AppLock {
    pub fn new() -> Self {
        Self::with_storage(Box::new(InMemoryAppLockStorage::default()))
    }

    pub fn with_storage(storage: Box<dyn AppLockStorage>) -> Self {
        let state = storage.load_state().unwrap_or_default();
        Self { state, storage }
    }

    pub fn state(&self) -> &AppLockState {
        &self.state
    }

    fn persist(&self) {
        self.storage.store_state(&self.state);
    }

    pub fn set_pin(&mut self, pin: &str, allow_biometric: bool) -> Result<(), AppLockError> {
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        let hash = argon2
            .hash_password(pin.as_bytes(), &salt)
            .map_err(|_| AppLockError::InvalidPin)?
            .to_string();
        self.state.hashed_pin = Some(hash);
        self.state.allow_biometric = allow_biometric;
        self.state.failed_attempts = 0;
        self.state.locked = false;
        self.persist();
        Ok(())
    }

    pub fn verify_pin(&mut self, pin: &str) -> Result<(), AppLockError> {
        if self.state.locked {
            return Err(AppLockError::Locked);
        }
        let Some(hash) = &self.state.hashed_pin else {
            return Err(AppLockError::NotConfigured);
        };
        let parsed = PasswordHash::new(hash).map_err(|_| AppLockError::InvalidPin)?;
        match Argon2::default().verify_password(pin.as_bytes(), &parsed) {
            Ok(_) => {
                self.state.failed_attempts = 0;
                self.state.locked = false;
                self.persist();
                Ok(())
            }
            Err(_) => {
                self.state.failed_attempts += 1;
                if self.state.failed_attempts >= MAX_FAILED_ATTEMPTS {
                    self.state.locked = true;
                }
                self.persist();
                Err(AppLockError::InvalidPin)
            }
        }
    }

    pub fn mark_biometric_success(&mut self) -> Result<(), AppLockError> {
        if !self.state.is_configured() {
            return Err(AppLockError::NotConfigured);
        }
        self.state.failed_attempts = 0;
        self.state.locked = false;
        self.persist();
        Ok(())
    }

    pub fn reset_with_token(&mut self, token: &ResetToken) -> Result<(), AppLockError> {
        if !token.is_valid() {
            return Err(AppLockError::InvalidResetToken);
        }
        self.state = AppLockState::new();
        self.storage.clear_state();
        Ok(())
    }
}

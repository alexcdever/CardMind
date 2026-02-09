//! Loro export/import API functions for Flutter
//!
//! This module provides functions to export and import Loro snapshots
//! for data backup and restore.

use crate::api::card::get_card_store_arc;
use crate::models::error::{CardMindError, Result};
use serde::{Deserialize, Serialize};

/// Export all cards as JSON
///
/// This function exports all card data as JSON that can be saved as a backup file.
///
/// # Returns
///
/// JSON string containing all cards
///
/// # Example (Dart)
///
/// ```dart
/// final json = await loroExportSnapshot();
/// // Save json to file
/// ```
#[flutter_rust_bridge::frb]
pub fn loro_export_snapshot() -> Result<String> {
    let store = get_card_store_arc()?;
    let store = store.lock().unwrap();

    // Get all cards (including deleted ones for complete backup)
    let cards = store.get_all_cards()?;

    // Serialize to JSON
    let json = serde_json::to_string_pretty(&cards)?;
    Ok(json)
}

/// File preview information
#[derive(Debug, Clone, Serialize, Deserialize)]
#[flutter_rust_bridge::frb]
pub struct FilePreview {
    /// Number of cards in the file
    pub card_count: usize,

    /// File format version (for future compatibility)
    pub format_version: String,

    /// Estimated file size in bytes
    pub file_size: usize,
}

/// Parse a backup file and return preview information
///
/// This function validates and previews a backup file without importing it.
///
/// # Arguments
///
/// * `data` - JSON string of the backup file
///
/// # Returns
///
/// FilePreview with information about the file contents
///
/// # Example (Dart)
///
/// ```dart
/// final preview = await loroParseFile(data: jsonString);
/// print('Cards: ${preview.cardCount}');
/// ```
#[flutter_rust_bridge::frb]
pub fn loro_parse_file(data: String) -> Result<FilePreview> {
    // Validate file size (max 100MB)
    const MAX_FILE_SIZE: usize = 100 * 1024 * 1024;
    if data.len() > MAX_FILE_SIZE {
        return Err(CardMindError::IoError(
            "File size exceeds 100MB limit".to_string(),
        ));
    }

    // Try to parse the JSON
    let cards: Vec<crate::models::card::Card> = serde_json::from_str(&data)
        .map_err(|e| CardMindError::SerializationError(format!("Invalid backup file: {}", e)))?;

    Ok(FilePreview {
        card_count: cards.len(),
        format_version: "1.0".to_string(),
        file_size: data.len(),
    })
}

/// Import and merge data from a backup file
///
/// This function imports cards from a backup file and merges them
/// with existing data by comparing timestamps.
///
/// # Arguments
///
/// * `data` - JSON string of the backup file
///
/// # Returns
///
/// Number of cards imported
///
/// # Example (Dart)
///
/// ```dart
/// final count = await loroImportMerge(data: jsonString);
/// print('Imported $count cards');
/// ```
#[flutter_rust_bridge::frb]
pub fn loro_import_merge(data: String) -> Result<usize> {
    // Validate file size
    const MAX_FILE_SIZE: usize = 100 * 1024 * 1024;
    if data.len() > MAX_FILE_SIZE {
        return Err(CardMindError::IoError(
            "File size exceeds 100MB limit".to_string(),
        ));
    }

    // Parse the import data
    let import_cards: Vec<crate::models::card::Card> = serde_json::from_str(&data)
        .map_err(|e| CardMindError::SerializationError(format!("Invalid backup file: {}", e)))?;

    let store = get_card_store_arc()?;
    let mut store = store.lock().unwrap();

    let mut imported_count = 0;

    // Import each card
    for card in import_cards {
        // Check if card already exists
        let existing_card = store.get_card_by_id(&card.id);

        match existing_card {
            Ok(existing) => {
                // Card exists - merge by comparing timestamps
                if card.updated_at > existing.updated_at {
                    // Import is newer - update
                    store.update_card(
                        &card.id,
                        Some(card.title),
                        Some(card.content),
                        card.last_edit_peer.clone(),
                    )?;
                    if card.deleted && !existing.deleted {
                        store.delete_card(&card.id, card.last_edit_peer.clone())?;
                    }
                    imported_count += 1;
                }
                // If existing is newer, keep it (no action needed)
            }
            Err(CardMindError::CardNotFound(_)) => {
                // Card doesn't exist - create it
                store.create_card(
                    card.title,
                    card.content,
                    card.owner_type,
                    card.pool_id,
                    card.last_edit_peer,
                )?;
                imported_count += 1;
            }
            Err(e) => return Err(e),
        }
    }

    Ok(imported_count)
}

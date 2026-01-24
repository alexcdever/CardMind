# DeviceConfig Specification

## MODIFIED Requirements

### Requirement: Device configuration structure
需求：设备配置结构

The system SHALL provide a device configuration structure with unique device ID, device name, and optional pool ID.
The structure SHALL store a single `pool_id` and SHALL NOT include legacy fields `joined_pools`, `resident_pools`, or `last_selected_pool`.

系统应提供包含唯一设备 ID、设备名称和可选池 ID 的设备配置结构。
该结构应仅保留单一的 `pool_id`，并且不应包含 `joined_pools`、`resident_pools` 或 `last_selected_pool` 等旧字段。

**Data Structure | 数据结构**:

```rust
pub struct DeviceConfig {
    /// Unique device ID (UUID v7)
    /// 设备唯一 ID (UUID v7)
    pub device_id: String,

    /// Device nickname (auto-generated, modifiable)
    /// 设备昵称（自动生成，可修改）
    pub device_name: String,

    /// Current joined pool ID (single value)
    /// 当前加入的数据池 ID（单值）
    pub pool_id: Option<String>,

    /// Last update timestamp
    /// 最后更新时间
    pub updated_at: i64,
}
```

#### Scenario: Persisted config uses single pool field
场景：持久化配置使用单一池字段

- **WHEN** the device configuration is serialized to JSON
- **操作**：设备配置序列化为 JSON
- **THEN** it SHALL include `device_id`, `device_name`, `pool_id`, and `updated_at`
- **预期结果**：应包含 `device_id`、`device_name`、`pool_id` 和 `updated_at`
- **AND** it SHALL NOT include `joined_pools`, `resident_pools`, or `last_selected_pool`
- **并且**：不应包含 `joined_pools`、`resident_pools` 或 `last_selected_pool`

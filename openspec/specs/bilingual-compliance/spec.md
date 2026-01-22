# bilingual-compliance Specification

## Purpose
TBD - created by archiving change bilingual-spec-compliance. Update Purpose after archive.
## Requirements
### Requirement: All section headings must be bilingual

The system SHALL ensure all section headings (## and ### levels) have both English and Chinese versions.

系统应确保所有章节标题（## 和 ### 级别）同时具有英文和中文版本。

#### Scenario: Section heading has Chinese translation
- **WHEN** a spec file contains a section heading like `## Overview`
- **操作**：规格文件包含章节标题如 `## Overview`
- **THEN** it SHALL be followed by `## 概述` on the next line
- **预期结果**：下一行应为 `## 概述`

### Requirement: Metadata must use bilingual format

The system SHALL ensure metadata fields use the format `**Key** | **键**: value`.

系统应确保元数据字段使用格式 `**Key** | **键**: value`。

#### Scenario: Metadata field is bilingual
- **WHEN** a spec file contains metadata like Version
- **操作**：规格文件包含元数据如 Version
- **THEN** it SHALL use format `**Version** | **版本**: 1.0.0`
- **预期结果**：应使用格式 `**Version** | **版本**: 1.0.0`

### Requirement: Requirement headings must be bilingual

The system SHALL ensure all Requirement headings have both English and Chinese versions.

系统应确保所有需求标题同时具有英文和中文版本。

#### Scenario: Requirement heading is bilingual
- **WHEN** a spec file contains `## Requirement: Title`
- **操作**：规格文件包含 `## Requirement: Title`
- **THEN** it SHALL be followed by `## 需求：标题`
- **预期结果**：应紧跟 `## 需求：标题`

### Requirement: Scenario headings must be bilingual

The system SHALL ensure all Scenario headings have both English and Chinese versions.

系统应确保所有场景标题同时具有英文和中文版本。

#### Scenario: Scenario heading is bilingual
- **WHEN** a spec file contains `### Scenario: Title`
- **操作**：规格文件包含 `### Scenario: Title`
- **THEN** it SHALL be followed by `### 场景：标题`
- **预期结果**：应紧跟 `### 场景：标题`


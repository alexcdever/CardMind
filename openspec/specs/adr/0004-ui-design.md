# ADR-0004: UI Design System
# ADR-0004：UI 设计系统

**Status**: Accepted  
**Date**: 2026-01-08  
**Deciders**: CardMind Team

---

## Overview | 概述

This document records UI design system decisions including colors, typography, spacing, and layout.

---

## 1. Color System | 颜色系统

### Primary Color: Teal | 主色：青色

**Decision**: Use **Teal (#00BFA5)** as the primary color.

| Competitor | Primary Color |
|------------|---------------|
| Notion | Purple |
| Obsidian | Purple/Blue |
| **CardMind** | **Teal** |

### Requirement: Color Application

The system SHALL use consistent color semantics.

#### Scenario: Success state
- GIVEN an operation completes successfully
- WHEN displaying feedback
- THEN the system SHALL use green color

#### Scenario: Error state
- GIVEN an error occurs
- WHEN displaying error feedback
- THEN the system SHALL use red color

---

## 2. Typography | 排版

### Font Family | 字体系列

**Decision**: Use platform-native system fonts.

| Platform | Font |
|----------|------|
| iOS | SF Pro |
| Android | Roboto |
| Windows | Segoe UI |
| macOS | SF Pro |
| Linux | Cantarell |

### Requirement: Typography Scale

The system SHALL use consistent typography hierarchy.

| Style | Size | Weight |
|-------|------|--------|
| Display | 32sp | Bold |
| Headline | 24sp | SemiBold |
| Title | 20sp | Medium |
| Body | 16sp | Regular |
| Caption | 12sp | Regular |

---

## 3. Spacing System | 间距系统

### Grid Baseline

**Decision**: Use 8px baseline grid for consistent spacing.

### Requirement: Spacing Application

The system SHALL use 8px increments for all spacing.

#### Scenario: Component padding
- GIVEN a card component
- WHEN applying internal padding
- THEN the padding SHALL be multiples of 8px (8, 16, 24, etc.)

#### Scenario: Component spacing
- GIVEN multiple components in a layout
- WHEN spacing between components
- THEN the gap SHALL be multiples of 8px

---

## 4. Layout System

### Responsive Design

**Decision**: Support phone, tablet, and desktop form factors.

### Requirement: Responsive Layout

The system SHALL adapt layout based on screen size.

#### Scenario: Phone layout
- GIVEN a device with width < 600dp
- WHEN rendering the main content
- THEN use single-column layout

#### Scenario: Tablet layout
- GIVEN a device with width >= 600dp
- WHEN rendering the main content
- THEN use two-column layout

---

**Related Documents**: [UI Design System](../../docs/interaction/ui_design_system.md)

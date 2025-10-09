# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚀 Quick Start Commands

### Development
- `pnpm dev:web` - Start web PWA development server
- `pnpm dev:electron` - Start Electron desktop app development
- `pnpm --filter @cardmind/relay dev` - Start real-time collaboration service

### Building
- `pnpm build` - Build all applications
- `pnpm build:web` - Build web PWA only
- `pnpm build:electron` - Build Electron desktop app
- `pnpm build:docker` - Build Docker container

### Testing & Quality
- `pnpm test` - Run all tests
- `pnpm lint` - Run ESLint
- `pnpm format` - Format code with Prettier
- `pnpm type-check` - Run TypeScript type checking

## 🏗️ Architecture Overview

### Monorepo Structure
```
CardMind/
├── apps/
│   ├── web/          # React + Vite PWA (IndexedDB + Yjs)
│   ├── electron/     # Electron desktop app (uses web build)
│   └── docker/       # Docker deployment
├── packages/
│   ├── shared/       # Common utilities (DB, sync)
│   ├── types/        # TypeScript definitions
│   └── relay/        # WebSocket collaboration server
└── src/              # Legacy source (being migrated)
```

### Core Technologies
- **Frontend**: React 18 + TypeScript + Vite
- **State**: Zustand stores for blocks and settings
- **Storage**: IndexedDB via Dexie (local-first)
- **Sync**: Yjs for real-time collaboration
- **UI**: Ant Design + Tailwind CSS

### Key Data Models
- `Block` - Knowledge cards with title/content/metadata
- `AppSettings` - Relay configuration and app preferences
- `RelaySettings` - WebSocket server connection details

### Data Flow
1. **Local Storage**: IndexedDB via `blockManager.ts` (Dexie)
2. **State Management**: Zustand stores (`blockManager.ts`, `settingsManager.ts`)
3. **Real-time Sync**: Yjs documents for blocks and settings
4. **Collaboration**: WebSocket relay service (`@cardmind/relay`)

### Development Context
- All new development uses the monorepo structure in `apps/`
- Legacy code in `/src` is being migrated to packages
- Chinese comments are required for new code
- TypeScript strict mode enabled
- pnpm workspaces manage dependencies

### Environment Requirements
- Node.js >= 18.0.0
- pnpm >= 8.0.0
- Git
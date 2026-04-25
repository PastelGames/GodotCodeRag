# Godot RAG - Implementation Plan

## Project Overview

**Project Name**: Godot RAG (Code RAG Explorer)
**Target Engine**: Godot 4.x
**Purpose**: Editor plugin for semantic search of Godot project files using Ollama embeddings
**Storage**: YAML file at `{project_dir}/data/rag_index.yaml`

---

## Architecture

```
addons/godot_rag/
├── plugin.gd                      # Godot plugin entry point
├── rag_explorer.gd             # Main dockable panel
├── core/
│   ├── code_scanner.gd         # File traversal + chunking
│   ├── embedder.gd            # Ollama API integration
│   ├── vector_store.gd        # Vector DB + cosine search
│   └── data_manager.gd       # YAML persistence
└── ui/
    └── settings_dialog.gd    # Ignore patterns + config
```

---

## Core Features

### 1. Indexing Pipeline

| Feature | Value |
|---------|-------|
| Supported extensions | `.gd`, `.tscn`, `.tres`, `.shader`, `.gdshader`, `.gml`, `.cfg`, `.ini`, `.json`, `.md`, `.txt`, `.yaml`, `.yml` |
| Ignored folders | Configurable (default: `.git`, `.godot`, `node_modules`) |
| Ignored files | Configurable (default: empty) |
| Chunk size | 50 lines |
| Overlap | 10 lines |
| Delimiter | Space |
| Embedding model | `nomic-embed-text` |
| Ollama endpoint | `http://localhost:11434` |

### 2. Storage Format (YAML)

```yaml
version: "1.0"
config:
  ignored_folders:
    - ".git"
    - ".godot"
    - "node_modules"
  ignored_files: []
  chunk_size: 50
  chunk_overlap: 10
last_indexed: "2026-04-25T12:00:00"
indexes:
  - path: "res://scripts/player.gd"
    chunk_id: 0
    start_line: 1
    end_line: 50
    content: "..."
    embedding: [0.1, 0.2, ...]
```

### 3. UI Components

- **Main Panel**: Dockable EditorPanel with search bar
- **Top K Control**: SpinBox (1-50, default 10)
- **Results Display**: ScrollContainer with expandable items
- **Buttons**: Copy All, Copy Prompt, Clear, Re-index, Settings
- **Status Bar**: File count, chunk count, indexing progress

### 4. Copy Functions

- **Copy All**: All snippets concatenated with `---` delimiter
- **Copy Prompt**: Full RAG prompt with context + user query

---

## Implementation Phases

### Phase 1: Core Infrastructure

1. `plugin.gd` - EditorPlugin registration
2. `core/code_scanner.gd` - File walking + chunking with ignore support
3. `core/data_manager.gd` - YAML read/write

### Phase 2: Embedding System

4. `core/embedder.gd` - Ollama HTTP client
5. `core/vector_store.gd` - Vector storage + cosine search

### Phase 3: UI Implementation

6. `rag_explorer.gd` - Main panel with search
7. `ui/settings_dialog.gd` - Ignore patterns + config
8. Snippet list display + copy functions

### Phase 4: Polish

9. Progress indicators
10. Error handling
11. Toolbar integration

---

## API Endpoints Used

| Endpoint | Method | Payload |
|----------|--------|---------|
| `/api/embeddings` | POST | `{"model": "nomic-embed-text", "prompt": text}` |
| `/api/tags` | GET | (none) |

---

## User Interactions

1. **Index Files**: Click "Index" button → scan → embed → save
2. **Search**: Enter query → embed → top-k search → display results
3. **Copy All**: Click button → clipboard with all snippets
4. **Copy Prompt**: Select results → click button → prompt with context
5. **Clear**: Click "Clear" → confirm → remove YAML
6. **Re-index**: Click "Re-index" → rebuild from scratch
7. **Settings**: Click gear → configure ignores + options → save

---

## Configuration Settings

| Setting | Type | Default |
|---------|------|---------|
| `ignored_folders` | String[] | `[".git", ".godot", "node_modules"]` |
| `ignored_files` | String[] | `[]` |
| `chunk_size` | int | 50 |
| `chunk_overlap` | int | 10 |
| `top_k_default` | int | 10 |
| `ollama_url` | String | `"http://localhost:11434"` |

---

## Acceptance Criteria

- [ ] Plugin loads in Godot 4.x editor
- [ ] Can index all .gd, .tscn, .tres files in project
- [ ] Configurable ignored_folders via settings
- [ ] Configurable ignored_files via settings
- [ ] Embeddings stored in YAML file
- [ ] Search returns relevant top-k results
- [ ] Copy All copies all snippets to clipboard
- [ ] Copy Prompt builds proper RAG prompt
- [ ] Top K is configurable (1-50)
- [ ] Clear removes all embeddings
- [ ] Re-index rebuilds from fresh scan
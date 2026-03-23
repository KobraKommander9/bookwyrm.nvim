# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Bookwyrm.nvim is a Neovim plugin for managing notes and notebooks. It is written in Lua and uses SQLite for persistence. The `master` branch holds the scaffold; the `setup` branch holds the full implementation.

## Development

This is a pure Lua Neovim plugin with no build step. There is currently no test runner or linter configured.

To test the plugin manually, load it in Neovim:
```vim
:set runtimepath+=path/to/bookwyrm.nvim
:lua require('bookwyrm').setup()
```

## Architecture

### Entry Points

- `plugin/bookwyrm.vim` — Vim-side loader; guards against double-loading and enforces Neovim requirement
- `lua/bookwyrm/init.lua` — Main Lua module; exposes `setup(config)` and the public API

### Module Layout (setup branch)

```
lua/bookwyrm/
├── init.lua          # Plugin setup, merges user config with defaults, exposes M.api
├── state.lua         # Singleton state: active notebook, merged config, lazy DB handle
├── types.lua         # Lua type annotations (Note, Notebook, Anchor, Link, Tag, Task, ...)
├── parser.lua        # Pure Lua markdown parser (anchors, links, aliases, tags, tasks)
├── api/
│   ├── init.lua      # Combines notes, notebooks, and hooks sub-APIs into one table
│   ├── notes.lua     # Capture floating buffer, template rendering, filesystem sync
│   ├── notebooks.lua # Register / list / set active notebook
│   └── hooks.lua     # Register and fire lifecycle events
├── db/
│   ├── init.lua      # SQLite connection, schema creation, migrations
│   ├── note.lua      # Note CRUD
│   ├── notebook.lua  # Notebook CRUD
│   └── queries.lua   # Batch query helpers
└── util/
    ├── notify.lua    # vim.notify wrappers (error / info / warn)
    └── paths.lua     # Path normalization, ensure_dir, filename helpers
```

### Data Flow

1. User calls `require('bookwyrm').setup(opts)` → merges opts into defaults → stores in `state`.
2. User commands (defined in `plugin/bookwyrm.lua`) call into `M.api.*` functions.
3. API functions read/write state and delegate persistence to `db/` modules.
4. `parser.lua` is stateless; it receives buffer lines and returns structured tables.

### Key Design Decisions

- **State is a module-level singleton** (`state.lua`). The DB connection is opened lazily on first use.
- **Template variables** (`{{date}}`, `{{time}}`, `{{datetime}}`, `{{notebook}}`, etc.) are expanded at note-capture time in `api/notes.lua`.
- **Markdown anchors** support three forms: range `[^start:id]...[^end:id]`, span `[content]^id`, and block `^id`.
- **Schema migrations** are handled in `db/init.lua`; add new migrations as numbered entries in the migrations table.

### User Commands

| Command | Description |
|---|---|
| `BookwyrmSync` | Sync the SQLite database with the filesystem |
| `BookwyrmNotebookRegister` | Register a new notebook |
| `BookwyrmNotebookDelete` | Unregister the active notebook |

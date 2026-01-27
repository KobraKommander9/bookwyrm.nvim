---@meta

---@class BookwyrmAlias
---@field alias string # Alias
---@field id integer # Alias ID
---@field note_id integer # ID of aliased note

---@class BookwyrmLink
---@field id integer # Link ID
---@field note_id integer # ID of linked note
---@field target string # Target link text
---@field line integer # Line nr of link in note
---@field col integer # Column nr of link in note
---@field content string|nil # Optional: line content for fast preview

---@class BookwyrmTask
---@field content string # Task content
---@field completed boolean # If task was completed
---@field id integer # Task ID
---@field line integer # Line nr of task in note
---@field note_id integer # ID of note where task is located

---@class BookwyrmNote
---@field aliases BookwyrmAlias[]
---@field id integer # Note ID
---@field links BookwyrmLink[]
---@field path string # Absolute note path
---@field tasks BookwyrmTask[]
---@field title string # Title of note
---@field type string|nil # Type of note
---@field update_time integer # Unix timestamp or iso string

---@meta

---@class RangeEntry
---@field line integer # Line number
---@field character integer # Character position

---@class Range
---@field start RangeEntry # Start of range
---@field end RangeEntry # End of range

---@class BookwyrmAlias
---@field alias string # Alias
---@field note_id integer # ID of aliased note

---@class BookwyrmAnchor
---@field anchor_id string # Unique anchor identifier
---@field content string # Anchor content
---@field loc Range # Anchor location
---@field note_id integer # ID of linked note

---@class BookwyrmLink
---@field col integer # Column nr of link in note
---@field content string # Link content
---@field line integer # Line nr of link in note
---@field note_id integer # ID of linked note
---@field target_anchor string|nil # Target anchor id, if any
---@field target_note string # Title of target note

---@class BookwyrmTag
---@field tag string # Tag
---@field note_id integer # ID of aliased note

---@class BookwyrmTask
---@field content string # Task content
---@field completed boolean # If task was completed
---@field id integer # Task ID
---@field line integer # Line nr of task in note
---@field note_id integer # ID of note where task is located

---@class BookwyrmNote
---@field id integer # Note ID
---@field path string # Absolute note path
---@field title string # Title of note
---@field update_time integer # Unix timestamp or iso string
---
---@field aliases BookwyrmAlias[]
---@field anchors BookwyrmAnchor[]
---@field links BookwyrmLink[]
---@field tags BookwyrmTag[]
---@field tasks BookwyrmTask[]

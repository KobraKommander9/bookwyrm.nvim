--- @meta

--- @class RangeEntry
--- @field line integer # Line number
--- @field character integer # Character position

--- @class Range
--- @field start RangeEntry # Start of range
--- @field finish RangeEntry # End of range

--- @class BookwyrmAlias
--- @field alias string # Alias
--- @field note_id integer # ID of aliased note

--- @class BookwyrmAnchor
--- @field anchor_id string # Unique anchor identifier
--- @field content string # Anchor content
--- @field loc Range # Anchor location
--- @field note_id integer # ID of linked note

--- @class BookwyrmLink
--- @field alias string? # The link alias
--- @field context string # Link context
--- @field loc Range # Link location
--- @field note_id integer # ID of linked note
--- @field target_anchor string? # Target anchor id, if any
--- @field target_note string? # Title of target note

--- @class BookwyrmTag
--- @field note_id integer # ID of aliased note
--- @field tag string # Tag

--- @class BookwyrmTask
--- @field content string # Task content
--- @field status integer # Task status
--- @field id integer # Task ID
--- @field line integer # Line nr of task in note
--- @field note_id integer # ID of note where task is located

--- @class BookwyrmNote
--- @field id integer # Note ID
--- @field path string # Absolute note path
--- @field title string # Title of note
---
--- @field aliases BookwyrmAlias[]
--- @field anchors BookwyrmAnchor[]
--- @field links BookwyrmLink[]
--- @field tags BookwyrmTag[]
--- @field tasks BookwyrmTask[]

--- @class BookwyrmBook
--- @field active integer # 1 if active
--- @field db_path string # Absolute path to notebook db
--- @field id integer # Noteboook ID
--- @field path string # Absolute path to notebook
--- @field title string # Notebook title

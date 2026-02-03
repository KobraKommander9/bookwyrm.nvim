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
--- @field type "range"|"span"|"block" # The type of anchor

--- @class BookwyrmLink
--- @field alias string? # The link alias
--- @field context string # Link context
--- @field id integer # The link id
--- @field loc Range # Link location
--- @field note_id integer # ID of owning note
--- @field target_anchor string? # Target anchor id, if any
--- @field target_note string? # Title of target note
--- @field target_note_id integer? # The id of the target note

--- @class BookwyrmTag
--- @field note_id integer # ID of aliased note
--- @field tag string # Tag

--- @class BookwyrmTask
--- @field content string # Task content
--- @field id integer # Task ID
--- @field line integer # Line nr of task in note
--- @field note_id integer # ID of note where task is located
--- @field status integer # Task status

--- @class BookwyrmNote
--- @field fsize integer # The size of the file
--- @field id integer # Note ID
--- @field mtime integer # The last modified time
--- @field notebook_id integer # The id of the owning notebook
--- @field relative_path string # The relative path within the notebook
--- @field title string # Title of note
---
--- @field aliases BookwyrmAlias[]
--- @field anchors BookwyrmAnchor[]
--- @field links BookwyrmLink[]
--- @field tags BookwyrmTag[]
--- @field tasks BookwyrmTask[]

--- @class BookwyrmBook
--- @field id integer # Noteboook ID
--- @field is_default boolean # If the notebook is the default active
--- @field priority integer # The prirotiy for syncing and note matches
--- @field root_path string # Absolute path to notebook root
--- @field title string # Notebook title

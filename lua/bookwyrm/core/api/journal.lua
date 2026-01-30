--- @class BookwyrmJournalAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local state = require("bookwyrm.core.state")

--- @class BookwyrmJournalAPI.CreateNoteOpts
--- @field open boolean? # If true, open note

--- Creates a new note in the active notebook. Returns the path to
--- the created note.
---
--- @param title string # The name of the note
--- @param opts BookwyrmJournalAPI.CreateNoteOpts # Create note opts
--- @return string?
function M.create_note(title, opts)
	notify.error("create_note unimplemented")
end

return M

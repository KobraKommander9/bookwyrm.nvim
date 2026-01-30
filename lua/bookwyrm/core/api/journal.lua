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
	if not state.nb then
		return nil
	end

	notify.error("create_note unimplemented")
end

--- Deletes the specified note.
---
--- @param id integer # The id of the note to delete
function M.delete_note(id)
	if not state.nb then
		return
	end

	notify.error("delete_note unimplemented")
end

--- Lists all notes in the active notebook.
---
--- @return BookwyrmNote[]
function M.list_notes()
	if not state.nb then
		return {}
	end

	notify.error("list_notes unimplemented")

	return {}
end

return M

--- @class BookwyrmPickersAPI
local M = {}

local state = require("bookwyrm.state")

--- @class BookwyrmPickerNote
--- @field title string # The note title
--- @field path string # Relative path within the notebook root
--- @field aliases string[] # List of aliases for the note
--- @field tags string[] # List of tags attached to the note

--- @class BookwyrmGetNotesOpts

--- Returns all notes in the active notebook as plain Lua tables suitable for
--- use in picker UIs (e.g. telescope, fzf-lua, snacks).
---
--- Returns an empty list when no active notebook is set. The optional `opts`
--- table is reserved for future filtering extensions and is currently unused.
---
--- @param opts BookwyrmGetNotesOpts?
--- @return BookwyrmPickerNote[]
function M.get_notes(opts)
	_ = opts

	local nb_id = state.get_active_id()
	if not nb_id then
		return {}
	end

	local db = state.get_conn()
	if not db then
		return {}
	end

	local raw_notes = db.notes:list_by_notebook(nb_id)

	local result = {}
	for _, note in ipairs(raw_notes) do
		local alias_rows = db.conn:select("aliases", { where = { note_id = note.id } }) or {}
		local tag_rows = db.conn:select("tags", { where = { note_id = note.id } }) or {}

		local aliases = vim.tbl_map(function(a)
			return a.alias
		end, alias_rows)

		local tags = vim.tbl_map(function(t)
			return t.tag
		end, tag_rows)

		table.insert(result, {
			title = note.title,
			path = note.relative_path,
			aliases = aliases,
			tags = tags,
		})
	end

	return result
end

return M

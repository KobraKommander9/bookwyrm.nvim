local M = {}

local DB = require("bookwyrm.db")

-------------------------------------------------------------------------------
--- Notes
-------------------------------------------------------------------------------

--- Creates a new note file in the active notebook.
---
--- @param title string # the title of the new note
function M.create_note(title)
	if not DB then
		return
	end

	DB.create_note(title)
end

--- Returns all notes for the active notebook.
---
--- @return BookwyrmNote[]
function M.get_notes()
	if not DB then
		return {}
	end

	return DB.get_notes()
end

return M

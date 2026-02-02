--- @class BookwyrmState
--- @field cfg BookwyrmConfig
--- @field db BookwyrmDB?
--- @field nb BookwyrmBook?
local M = {}

local notify = require("bookwyrm.util.notify")

--- @class BookwyrmNoteTemplate
--- @field path string # The path to the new note
--- @field header string? # The header to write to the new note
--- @field prefix string? # The prefix to write on each captured line
--- @field variables table<string, any>? # User defined variables

--- @class BookwyrmConfig
--- @field data_path string
--- @field db_path string
--- @field mappings BookwyrmMappings
--- @field silent boolean?
--- @field templates table<string, BookwyrmNoteTemplate>?

--- @class BookwyrmMappings
--- @field close string # The close key mapping
--- @field save string # The save key mapping

--- Ensures that there is an active notebook, falling back to the default if
--- necessary. This will not guarantee a notebook if no notebook has been
--- registered.
function M.ensure_active()
	if M.nb then
		return
	end

	local default = M.get_conn().notebooks:get_default()
	M.set_active(default)
end

--- Returns the active notebook id, if any.
---
--- @return integer?
function M.get_active_id()
	return M.nb and M.nb.id
end

--- Gets the current db connection.
---
--- @return BookwyrmDB
function M.get_conn()
	if not M.db then
		M.db = require("bookwyrm.db").open(M.cfg.db_path, M.cfg.silent)
		if not M.db then
			error("Could not get db connection")
		end
	end

	return M.db
end

--- Sets the active notebook.
---
--- @param nb? BookwyrmBook
function M.set_active(nb)
	if not nb then
		return
	end

	if not M.nb or M.nb.id ~= nb.id then
		M.nb = nb
		notify.info("Bookwyrm Switched to " .. M.nb.title, M.cfg.silent)
	end
end

return M

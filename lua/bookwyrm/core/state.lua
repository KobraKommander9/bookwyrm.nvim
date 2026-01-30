--- @class BookwyrmState
--- @field cfg BookwyrmConfig
--- @field db BookwyrmDB?
--- @field nb BookwyrmNotebookDB?
local M = {}

local nb_db = require("bookwyrm.core.db.notebook")
local notify = require("bookwyrm.util.notify")

--- @class BookwyrmConfig
--- @field data_path string
--- @field registry_path string
--- @field notebook_dir string
--- @field silent boolean?

--- Closes the active notebook.
function M.close_notebook()
	if M.nb then
		M.nb:close()
		M.nb = nil
	end
end

--- Returns the active notebook id, if any.
---
--- @return integer?
function M.get_active_id()
	return M.nb and M.nb.book.id
end

--- Opens the specified notebook.
---
--- @param nb BookwyrmBook
function M.open_notebook(nb)
	M.close_notebook()

	M.nb = nb_db.open(nb, M.cfg.silent)
	if not M.nb then
		notify.error("failed to open notebook: " .. nb.title, M.cfg.silent)
	end
end

return M

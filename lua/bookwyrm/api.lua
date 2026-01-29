local M = {}

local DB = require("bookwyrm.db")

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

--- Returns all the registered notebooks.
---
--- @return BookwyrmBook[]
function M.get_notebook_list()
	if not DB then
		return {}
	end

	return DB.get_notebooks()
end

--- Selects a notebook and makes it active.
---
--- @param id integer # The id of the notebook
function M.select_notebook(id)
	if not DB then
		return
	end

	DB.switch_to_notebook(id)
end

return M

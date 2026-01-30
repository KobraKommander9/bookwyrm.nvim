--- @class BookwyrmNotebookAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local state = require("bookwyrm.core.state")

--- Loads the default notebook, if one is set.
function M.load_default_notebook()
	if not state.db then
		return
	end

	notify.error("load_default_notebook unimplemented")
end

return M

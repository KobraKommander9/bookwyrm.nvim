--- Data source functions for picker integrations (e.g. telescope, fzf-lua).
---
--- @class BookwyrmPickersAPI
local M = {}

local state = require("bookwyrm.state")

--- Returns all registered notebooks as a list of BookwyrmBook tables.
---
--- @return BookwyrmBook[]
function M.get_notebooks()
	return state.get_conn().notebooks:list()
end

return M

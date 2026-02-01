--- @class BookwyrmState
--- @field cfg BookwyrmConfig
--- @field db BookwyrmDB?
--- @field active_nb BookwyrmBook?
local M = {}

--- @class BookwyrmConfig
--- @field data_path string
--- @field db_path string
--- @field silent boolean?

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

return M

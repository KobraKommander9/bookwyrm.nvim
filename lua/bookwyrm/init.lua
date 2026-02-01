local M = {}

local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.core.state")

--- @class BookwyrmAPI
M.api = require("bookwyrm.core.api")

--- @class BookwyrmOpts
--- @field data_path string? # The base path for the bookwyrm data
--- @field silent boolean? # If true silences notifications
local defaults = {
	data_path = vim.fn.stdpath("data") .. "/bookwyrm",
}

--- @param opts BookwyrmOpts
function M.setup(opts)
	state.cfg = vim.tbl_deep_extend("force", defaults, opts or {}) --[[@as BookwyrmConfig]]

	state.cfg.data_path = paths.normalize(state.cfg.data_path)
	paths.ensure_dir(state.cfg.data_path)

	state.cfg.db_path = state.cfg.data_path .. "/bookwyrm.db"

	local db = require("bookwyrm.core.db").open(state.cfg.registry_path, state.cfg.silent)
	if not db then
		return
	end

	state.db = db

	M.api.load_default_notebook()
end

return M

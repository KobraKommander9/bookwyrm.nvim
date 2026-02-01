local M = {}

local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

--- @class BookwyrmAPI
M.api = require("bookwyrm.api")

--- @class BookwyrmOpts
--- @field data_path string? # The base path for the bookwyrm data
--- @field silent boolean? # If true silences notifications
local defaults = {
	data_path = vim.fn.stdpath("data") .. "/bookwyrm",
}

--- Initializes the bookwyrm plugin.
---
--- @param opts BookwyrmOpts
function M.setup(opts)
	state.cfg = vim.tbl_deep_extend("force", defaults, opts or {}) --[[@as BookwyrmConfig]]

	state.cfg.data_path = paths.normalize(state.cfg.data_path)
	paths.ensure_dir(state.cfg.data_path)

	state.cfg.db_path = state.cfg.data_path .. "/bookwyrm.db"
end

return M

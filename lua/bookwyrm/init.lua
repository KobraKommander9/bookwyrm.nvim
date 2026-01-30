local M = {}

local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.core.state")

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

	state.cfg.registry_path = state.cfg.data_path .. "/bookwyrm.sqlite"
	state.cfg.notebook_dir = state.cfg.data_path .. "/notebooks"
	paths.ensure_dir(state.cfg.notebook_dir)

	--  local db = require("bookwyrm.db")
	-- if not db then
	-- 	require("bookwyrm.notify").error("unable to initialize notebook registry")
	-- 	return
	-- end
	--
	-- if not opts.recreate_registry then
	-- 	db.init_registry(options.registry_path)
	-- else
	-- 	db.migrate_registry(options.registry_path)
	-- end
	--
	-- db.load_active_notebook()
end

return M

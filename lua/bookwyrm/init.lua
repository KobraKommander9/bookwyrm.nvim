local M = {}

local hooks = require("bookwyrm.hooks")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

--- @class BookwyrmAPI
M.api = require("bookwyrm.api")

--- @class BookwyrmOpts
--- @field data_path string? # The base path for the bookwyrm data
--- @field disable_hooks boolean? # If true will disable hook registration
--- @field silent boolean? # If true silences notifications
--- @field templates table<string, BookwyrmNoteTemplate>? # Note templates
local defaults = {
	data_path = vim.fn.stdpath("data") .. "/bookwyrm",
	templates = {
		journal = {
			path = "journals/%Y-%m-%d",
			header = "### Capture: %H:%M",
		},
		todo = {
			path = "tasks.md",
			header = "## Added on %Y-%m-%d",
			prefix = "- [ ] ",
		},
	},
}

--- Initializes the bookwyrm plugin.
---
--- @param opts BookwyrmOpts
function M.setup(opts)
	opts = opts or {}

	state.cfg = vim.tbl_deep_extend("force", defaults, {}) --[[@as BookwyrmConfig]]

	state.cfg.data_path = paths.normalize(state.cfg.data_path)
	paths.ensure_dir(state.cfg.data_path)

	state.cfg.db_path = state.cfg.data_path .. "/bookwyrm.db"

	if not opts.disable_hooks then
		hooks.setup_context_switcher()
	end
end

return M

local M = {}

local hooks = require("bookwyrm.hooks")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

--- @class BookwyrmAPI
M.api = require("bookwyrm.api")

--- @class BookwyrmOpts
--- @field data_path string? # The base path for the bookwyrm data
--- @field disable_hooks boolean? # If true will disable hook registration
--- @field mappings BookwyrmMappings? # Key mapping overrides
--- @field note_capture BookwyrmCaptureNoteOpts? # Capture note options
--- @field silent boolean? # If true silences notifications
--- @field templates table<string, BookwyrmNoteTemplate>? # Note templates
local defaults = {
	data_path = vim.fn.stdpath("data") .. "/bookwyrm",
	mappings = {
		close = "q",
		save = "<C-s>",
	},
	note_capture = {
		buffer = {
			bufhidden = "wipe",
			filetype = "markdown",
		},
		window = {
			cursorline = true,
			foldcolumn = "0",
			number = true,
			numberwidth = 2,
			signcolumn = "no",
		},
	},
	templates = {
		journal = {
			header = "### Capture: {{time}}",
			path = "journals/{{date}}",
		},
		todo = {
			header = false,
			path = "tasks",
			prefix = "- [ ] TODO ",
		},
	},
}

--- Initializes the bookwyrm plugin.
---
--- @param opts BookwyrmOpts
function M.setup(opts)
	opts = opts or {}
	state.cfg = vim.tbl_deep_extend("force", defaults, opts) --[[@as BookwyrmConfig]]

	state.cfg.data_path = paths.normalize(state.cfg.data_path)
	paths.ensure_dir(state.cfg.data_path)

	state.cfg.db_path = state.cfg.data_path .. "/bookwyrm.db"

	if not opts.disable_hooks then
		hooks.setup_context_switcher()
		hooks.setup_watchdog()
	end
end

return M

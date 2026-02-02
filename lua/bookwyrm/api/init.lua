--- @class BookwyrmAPI: BookwyrmNotebookAPI, BookwyrmNoteAPI, BookwyrmHooksAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local state = require("bookwyrm.state")

local notebook = require("bookwyrm.api.notebooks")
local note = require("bookwyrm.api.notes")
local hooks = require("bookwyrm.api.hooks")

M = vim.tbl_extend("force", M, notebook, note, hooks)

--- Opens a floating buffer for capturing a new note.
---
--- @param opts BookwyrmNoteAPI.CaptureNoteOpts?
function M.open_capture(opts)
	state.ensure_active()
	if not state.nb then
		notify.error("No notebook available")
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

	local width = math.ceil(vim.o.columns * 0.4)
	local height = math.ceil(vim.o.lines * 0.3)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = 0,
		col = vim.o.columns - width,
		border = "rounded",
		title = " Quick Capture [" .. state.nb.title .. "] ",
		title_pos = "center",
	})

	local function submit()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		note.capture_note(lines, opts)
		vim.api.nvim_win_close(win, true)
	end

	vim.keymap.set("n", state.cfg.mappings.save, submit, { buffer = buf, desc = "Save Capture" })
	vim.keymap.set("i", state.cfg.mappings.save, submit, { buffer = buf, desc = "Save Capture" })

	vim.keymap.set("n", state.cfg.mappings.close, function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, desc = "Discard Capture" })
end

return M

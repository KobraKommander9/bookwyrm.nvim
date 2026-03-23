--- @class BookwyrmAPI: BookwyrmNotebookAPI, BookwyrmNoteAPI, BookwyrmHooksAPI
local M = {}

local uv = vim.uv or vim.loop

local notify = require("bookwyrm.util.notify")
local state = require("bookwyrm.state")

local notebook = require("bookwyrm.api.notebooks")
local note = require("bookwyrm.api.notes")
local hooks = require("bookwyrm.api.hooks")

M = vim.tbl_extend("force", M, notebook, note, hooks)

--- @class BookwyrmAPI.OpenCaptureOpts: BookwyrmNoteAPI.CaptureNoteOpts, BookwyrmCaptureNoteOpts

--- Opens a floating buffer for capturing a new note.
---
--- @param opts BookwyrmAPI.OpenCaptureOpts?
function M.open_capture(opts)
	opts = vim.tbl_deep_extend("force", state.cfg.note_capture, opts or {}) --[[@as BookwyrmAPI.OpenCaptureOpts]]
	opts.buffer = opts.buffer or {}
	opts.window = opts.window or {}

	state.ensure_active()
	if not state.nb then
		notify.error("No notebook available")
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	for k, v in pairs(opts.buffer) do
		vim.api.nvim_set_option_value(k, v, { buf = buf })
	end

	local width = math.ceil(vim.o.columns * 0.4)
	local height = math.ceil(vim.o.lines * 0.3)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = 0,
		col = vim.o.columns - width,
		style = "minimal",
		border = "rounded",
		title = " Quick Capture [" .. state.nb.title .. "] ",
		title_pos = "center",
	})

	for k, v in pairs(opts.window) do
		vim.api.nvim_set_option_value(k, v, { win = win })
	end

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

--- Synchronizes all notebooks with the filesystem.
function M.sync_db()
	local notebooks = state.get_conn().notebooks:list()

	notify.info("Starting full sync...", state.cfg.silent)
	local start_time = uv.hrtime()
	local count = 0

	for _, nb in ipairs(notebooks) do
		local scanner = vim.fs.dir(nb.root_path, { recursive = true })

		for name, type in scanner do
			if type == "file" and name:match("%.md$") then
				local full_path = nb.root_path .. "/" .. name

				local ok, err = pcall(note.sync_file, full_path)
				if ok then
					count = count + 1
				else
					notify.error("Error syncing " .. name .. ": " .. tostring(err), state.cfg.silent)
				end
			end
		end
	end

	local end_time = uv.hrtime()
	local duration = (end_time - start_time) / 1e6 -- convert to ms
	notify.info(string.format("Sync complete! Indexed %d files in %.2fms", count, duration))
end

return M

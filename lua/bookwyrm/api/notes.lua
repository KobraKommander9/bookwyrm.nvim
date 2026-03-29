--- @class BookwyrmNoteAPI
local M = {}

local hooks = require("bookwyrm.api.hooks")
local notify = require("bookwyrm.util.notify")
local parser = require("bookwyrm.parser")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

--- Builds the base template variable table, optionally merging extra vars.
---
--- Supports: {{date}}, {{time}}, {{datetime}}, {{notebook}},
---           {{path}}, {{relpath}}, {{source}}, {{line}}
---
--- @param extra table<string, any>? # Extra variables
--- @return table<string, string>
local function get_template_variables(extra)
	local vars = {
		date = os.date("%Y-%m-%d"),
		datetime = os.date("%Y-%m-%d %H:%M"),
		line = tostring(vim.fn.line("#")),
		notebook = state.nb and state.nb.title or "Unknown",
		path = vim.fn.expand("#:p"),
		relpath = vim.fn.expand("#:~"),
		source = vim.fn.expand("#:t"),
		time = os.date("%H:%M"),
	}

	for key, val in pairs(extra or {}) do
		if type(val) == "function" then
			vars[key] = val()
		else
			vars[key] = val
		end
	end

	return vars
end

--- Expands {{variable}} placeholders in a string.
---
--- @param str string
--- @param vars table<string, string>
--- @return string
local function parse_template(str, vars)
	return (str:gsub("{{%s*(.-)%s*}}", function(key)
		return vars[key] or ("{{" .. key .. "}}")
	end))
end

--- @class BookwyrmNoteAPI.CaptureNoteOpts
--- @field path string? # Relative path within the notebook root (without .md). Defaults to template path or "{{datetime}}"
--- @field tname string? # The note template name

--- Captures the provided lines into a new note using the specified template.
---
--- @param lines string[] # The lines to capture
--- @param opts BookwyrmNoteAPI.CaptureNoteOpts? # Capture options
--- @return string? # The absolute path of the created note, or nil on failure
function M.capture_note(lines, opts)
	opts = opts or {}

	state.ensure_active()
	if not state.nb then
		notify.error("No notebook available")
		return
	end

	local template = state.cfg.templates[opts.tname or ""] or {}
	local vars = get_template_variables(template.variables)

	local path = template.path or opts.path or "{{datetime}}"
	path = path:gsub("%.md$", "")
	path = paths.normalize_fname(path)

	local rel_path = paths.normalize_fname(parse_template(path, vars)) .. ".md"
	local full_path = state.nb.root_path .. "/" .. rel_path
	paths.ensure_dir(vim.fn.fnamemodify(full_path, ":h"))

	local content = { "" }

	if template.header then
		table.insert(content, template.header ~= "" and parse_template(template.header, vars) or "---\n")
	end

	for _, line in ipairs(lines) do
		local formatted = (template.prefix and parse_template(template.prefix, vars) or "") .. line
		table.insert(content, formatted)
	end

	local f = io.open(full_path, "a")
	if f then
		f:write(table.concat(content, "\n") .. "\n")
		f:close()
		M.sync_file(full_path)
		hooks.fire("note_captured", { path = full_path })
		return full_path
	else
		notify.error("Failed to open new note: " .. full_path, state.cfg.silent)
	end
end

--- @class BookwyrmAPI.CaptureOpts: BookwyrmNoteAPI.CaptureNoteOpts, BookwyrmCaptureNoteOpts

--- Opens a floating buffer pre-populated with a note template for quick capture.
---
--- The floating window uses `relative = "editor"` and is anchored to the
--- top-right corner. Template variables ({{date}}, {{time}}, {{datetime}},
--- {{notebook}}) are expanded at open time, not at write time.
---
--- @param opts BookwyrmAPI.CaptureOpts?
function M.capture(opts)
	opts = vim.tbl_deep_extend("force", state.cfg.note_capture, opts or {}) --[[@as BookwyrmAPI.CaptureOpts]]
	opts.buffer = opts.buffer or {}
	opts.window = opts.window or {}

	state.ensure_active()
	if not state.nb then
		notify.error("No notebook available")
		return
	end

	local template = state.cfg.templates[opts.tname or ""] or {}
	local vars = get_template_variables(template.variables)

	local buf = vim.api.nvim_create_buf(false, true)
	for k, v in pairs(opts.buffer) do
		vim.api.nvim_set_option_value(k, v, { buf = buf })
	end

	-- Pre-populate buffer with expanded template header
	if template.header then
		local header_text = template.header ~= "" and parse_template(template.header, vars) or ""
		if header_text ~= "" then
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(header_text, "\n"))
		end
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
		title = " Quick Capture [" .. state.nb.title .. "] " .. (opts.tname and "(" .. opts.tname .. ") " or ""),
		title_pos = "center",
	})

	for k, v in pairs(opts.window) do
		vim.api.nvim_set_option_value(k, v, { win = win })
	end

	local function submit()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		M.capture_note(lines, opts)
		vim.api.nvim_win_close(win, true)
	end

	vim.keymap.set("n", state.cfg.mappings.save, submit, { buffer = buf, desc = "Save Capture" })
	vim.keymap.set("i", state.cfg.mappings.save, submit, { buffer = buf, desc = "Save Capture" })

	vim.keymap.set("n", state.cfg.mappings.close, function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, desc = "Discard Capture" })
end

--- Opens a note file in the current window.
---
--- @param path string # The absolute path to the note file
function M.open(path)
	if not path or path == "" then
		notify.warn("No path provided", state.cfg.silent)
		return
	end

	vim.cmd("edit " .. vim.fn.fnameescape(path))
	hooks.fire("note_opened", { path = path })
end

--- Scans the active notebook directory, parses each markdown file with
--- parser.lua, and upserts all notes into the database.
function M.sync()
	state.ensure_active()
	if not state.nb then
		notify.error("No active notebook to sync", state.cfg.silent)
		return
	end

	local uv = vim.uv or vim.loop
	local nb = state.nb

	hooks.fire("pre_sync", { notebook = { id = nb.id, title = nb.title, root_path = nb.root_path } })
	notify.info("Syncing notebook: " .. nb.title, state.cfg.silent)
	local start_time = uv.hrtime()
	local count = 0

	local scanner = vim.fs.dir(nb.root_path, { recursive = true })

	for name, ftype in scanner do
		if ftype == "file" and name:match("%.md$") then
			local full_path = nb.root_path .. "/" .. name

			local ok, err = pcall(M.sync_file, full_path)
			if ok then
				count = count + 1
			else
				notify.error("Error syncing " .. name .. ": " .. tostring(err), state.cfg.silent)
			end
		end
	end

	local duration = (uv.hrtime() - start_time) / 1e6
	notify.info(string.format("Sync complete! Indexed %d files in %.2fms", count, duration))
	hooks.fire("post_sync", { notebook = { id = nb.id, title = nb.title, root_path = nb.root_path }, count = count, duration = duration })
end

--- Syncs a single file on disk with the database.
---
--- @param path string? # The absolute path to the file; defaults to the current buffer's file.
function M.sync_file(path)
	path = path or vim.api.nvim_buf_get_name(0)
	if not path or path == "" then
		return
	end
	path = paths.normalize(path)

	local ext = vim.fn.fnamemodify(path, ":e")
	if ext ~= "md" then
		return
	end

	local nb = state.get_conn().notebooks:get_by_path(path)
	if not nb then
		return
	end

	local root = nb.root_path .. "/"
	local rel_path = path:sub(#root + 1)

	local lines = vim.fn.readfile(path)
	local note = parser.parse(lines)
	note.relative_path = rel_path
	note.title = vim.fn.fnamemodify(path, ":t:r")
	note.fsize = vim.fn.getfsize(path)
	note.mtime = vim.fn.getftime(path)

	state.get_conn().notes:upsert_note(nb.id, note)
end

--- Syncs the current buffer content with the database.
---
--- @param bufnr integer? # The buffer number; defaults to the current buffer (0).
function M.sync_buffer(bufnr)
	bufnr = bufnr or 0
	if vim.bo[bufnr].filetype ~= "markdown" then
		return
	end

	local path = vim.api.nvim_buf_get_name(bufnr)
	if not path or path == "" then
		return
	end

	local nb = state.get_conn().notebooks:get_by_path(path)
	if not nb then
		return
	end

	local root = nb.root_path .. "/"
	local rel_path = path:sub(#root + 1)

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local note = parser.parse(lines)
	note.relative_path = rel_path
	note.title = vim.fn.fnamemodify(path, ":t:r")
	note.fsize = vim.fn.getfsize(path)
	note.mtime = vim.fn.getftime(path)

	state.get_conn().notes:upsert_note(nb.id, note)
end

--- @class BookwyrmListNotesOpts
--- @field nb_id integer? # The id of the notebook to list in, defaults to the active notebook.

--- Lists all notes in the active (or specified) notebook.
---
--- Returns an empty list when no active notebook is set. The optional `opts`
--- table is reserved for future filtering extensions.
---
--- @param opts BookwyrmListNotesOpts?
--- @return BookwyrmNote[]
function M.list_notes(opts)
	state.ensure_active()
	if not state.nb then
		return {}
	end

	local nb_id = (opts and opts.nb_id) or state.get_active_id()
	return state.get_conn().notes:list(nb_id)
end

--- Returns all notes that contain a link pointing to the given file.
---
--- Each entry contains:
---   - source_title  (string)  title of the linking note
---   - source_path   (string)  absolute path of the linking note
---   - anchor        (string?) target anchor id, if any
---   - context       (string?) surrounding text from the link
---
--- Returns an empty list when no backlinks exist or when no active notebook
--- is set.
---
--- @param file_path string # Absolute (or notebook-relative) path to the target note
--- @return BookwyrmBacklink[]
function M.get_backlinks(file_path)
	if not file_path or file_path == "" then
		return {}
	end

	state.ensure_active()
	if not state.nb then
		return {}
	end

	local nb = state.nb
	local root = nb.root_path .. "/"

	-- Normalise to an absolute path then derive the relative path.
	local abs_path = paths.normalize(file_path)
	if not abs_path:sub(1, #root) == root then
		-- file_path may already be relative; prepend root and normalise again
		abs_path = paths.normalize(root .. file_path)
	end

	local relative_path
	if abs_path:sub(1, #root) == root then
		relative_path = abs_path:sub(#root + 1)
	else
		relative_path = file_path
	end

	local db = state.get_conn()
	if not db then
		return {}
	end

	local rows = db.notes:get_backlinks(nb.id, relative_path)

	-- Convert relative source_path to absolute path for callers.
	local results = {}
	for _, row in ipairs(rows) do
		table.insert(results, {
			source_title = row.source_title,
			source_path = root .. row.source_path,
			anchor = row.anchor,
			context = row.context,
		})
	end

	return results
end

return M

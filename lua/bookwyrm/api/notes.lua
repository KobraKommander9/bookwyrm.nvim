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

	for key, val in pairs(state.cfg.template_variables or {}) do
		if type(val) == "function" then
			vars[key] = val()
		else
			vars[key] = val
		end
	end

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

--- Scans all markdown files in the given notebook directory and upserts them
--- into the database. Returns the count of successfully indexed files.
---
--- @param nb BookwyrmBook # The notebook to scan
--- @return integer # The number of files indexed
local function sync_all(nb)
	local count = 0

	for name, ftype in vim.fs.dir(nb.root_path, { recursive = true }) do
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

	return count
end

--- @class BookwyrmAPI.CaptureOpts: BookwyrmNoteAPI.CaptureNoteOpts, BookwyrmCaptureNoteOpts

--- Opens a floating buffer pre-populated with a note template for quick capture.
---
--- The floating window uses `relative = "editor"` and is anchored to the top-right.
--- Template variables ({{date}}, {{time}}, {{datetime}}, {{notebook}}) are
--- expanded at open time, not at write time.
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

	local orig_win = vim.api.nvim_get_current_win()
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
		row = 1,
		col = vim.o.columns - width - 2,
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
		vim.api.nvim_win_close(win, true)
		M.capture_note(lines, opts)
	end

	local function discard()
		vim.api.nvim_win_close(win, true)
		if vim.api.nvim_win_is_valid(orig_win) then
			vim.api.nvim_set_current_win(orig_win)
		end
	end

	vim.keymap.set({ "n", "i" }, state.cfg.mappings.save, submit, { buffer = buf, desc = "Save Capture" })
	vim.keymap.set("n", state.cfg.mappings.close, discard, { buffer = buf, desc = "Discard Capture" })
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

--- Returns the note for the given id.
---
--- @param id integer # The note id.
--- @return BookwyrmNote?
function M.get_note(id)
	return state.get_conn().notes:get(id)
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
--- @return BookwyrmLink[]
function M.get_backlinks(file_path)
	if not file_path or file_path == "" then
		return {}
	end

	state.ensure_active()

	local nb = state.nb
	if not nb then
		return {}
	end

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

	return db.notes:get_backlinks(nb.id, relative_path)
end

--- Inserts a `[[note title]]` wikilink at the given cursor position in the given buffer.
---
--- @param entry BookwyrmNote # A note entry as returned by `list_notes()`.
--- @param bufnr integer # The target buffer number
--- @param cursor integer[] # The cursor position as `{ row, col }` (1-indexed row, 1-indexed col)
function M.insert_link(entry, bufnr, cursor)
	if not entry or not entry.title then
		notify.warn("insert_link: entry must have a title field")
		return
	end

	local row = cursor[1] - 1 -- nvim_buf_set_text uses 0-indexed rows
	local col = cursor[2] - 1 -- nvim_buf_set_text uses 0-indexed cols
	local link = "[[" .. entry.title .. "]]"

	vim.api.nvim_buf_set_text(bufnr, row, col, row, col, { link })
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

--- @class BookwyrmNoteAPI.OpenOpts: BookwyrmCaptureNoteOpts
--- @field float? boolean # If the note should be opened as a float

--- Opens a note file in the current window.
---
--- @param note BookwyrmNote # The note to open
--- @param opts? BookwyrmNoteAPI.OpenOpts # If the note should be opened in the floating window
function M.open(note, opts)
	opts = vim.tbl_deep_extend("force", state.cfg.note_capture, opts or {}) --[[@as BookwyrmNoteAPI.OpenOpts]]
	opts.buffer = opts.buffer or {}
	opts.window = opts.window or {}

	local nb = state.get_conn().notebooks:get_by_id(note.notebook_id)
	if not nb then
		notify.error("Could not find notebook for note", state.cfg.silent)
		return
	end

	local path = nb.root_path .. "/" .. note.relative_path
	path = paths.normalize(path)

	if not opts.float then
		vim.cmd("edit " .. vim.fn.fnameescape(path))
		hooks.fire("note_opened", { path = path })
		return
	end

	local buf = vim.fn.bufnr(path)
	local is_new = buf == -1

	if is_new then
		buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(buf, path)
	end

	local width = math.ceil(vim.o.columns * 0.4)
	local height = math.ceil(vim.o.lines * 0.3)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = 1,
		col = vim.o.columns - width - 2,
		style = "minimal",
		border = "rounded",
		title = note.title,
		title_pos = "center",
	})

	if is_new or vim.api.nvim_buf_line_count(buf) <= 1 then
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("keepalt lockmarks silent 0read " .. vim.fn.fnameescape(path))
			vim.cmd("silent! $delete _")
			vim.cmd("filetype detect")
		end)
	end

	for k, v in pairs(opts.buffer) do
		vim.api.nvim_set_option_value(k, v, { buf = buf })
	end

	for k, v in pairs(opts.window) do
		vim.api.nvim_set_option_value(k, v, { win = win })
	end

	vim.api.nvim_set_option_value("modified", false, { buf = buf })
	vim.api.nvim_set_current_win(win)

	local line_count = vim.api.nvim_buf_line_count(buf)
	vim.api.nvim_win_set_cursor(win, { line_count, 0 })

	vim.keymap.set({ "n", "i" }, state.cfg.mappings.save, "<cmd>w<cr>", { buffer = buf, desc = "Save Capture" })
	vim.keymap.set("n", state.cfg.mappings.close, "<cmd>q<cr>", { buffer = buf, desc = "Discard Capture" })
end

--- Drops the SQLite database, re-creates it (schema + migrations), and
--- re-indexes all files in the active notebook from scratch.
---
--- Prompts the user for confirmation before proceeding. Exits early if no
--- active notebook is set.
function M.reset()
	state.ensure_active()

	local nb = state.nb
	if not nb then
		notify.error("No active notebook to reset", state.cfg.silent)
		return
	end

	local choice = vim.fn.confirm("Reset bookwyrm database? This cannot be undone.", "&Yes\n&No", 2)
	if choice ~= 1 then
		return
	end

	local db_path = state.cfg.db_path

	-- Close and discard the existing connection
	if state.db then
		pcall(function()
			state.db:close()
		end)
		state.db = nil
	end
	state.failed = nil

	-- Delete the DB file from disk
	local removed = os.remove(db_path)
	if not removed then
		notify.warn("Could not remove DB file (may not exist yet): " .. db_path, state.cfg.silent)
	end

	-- Re-initialize: open a fresh connection which applies schema + migrations
	local new_db = state.get_conn()
	if not new_db then
		notify.error("Failed to re-initialize database after reset", state.cfg.silent)
		return
	end

	-- Re-register the active notebook (it was wiped along with the DB)
	local new_id = new_db.notebooks:insert({
		root_path = nb.root_path,
		title = nb.title,
		priority = nb.priority or 0,
	})
	if not new_id then
		notify.error("Failed to re-register notebook after reset", state.cfg.silent)
		return
	end

	state.nb = {
		id = new_id,
		root_path = nb.root_path,
		title = nb.title,
		priority = nb.priority or 0,
		is_default = nb.is_default,
	}

	notify.info("Re-indexing notebook: " .. state.nb.title, state.cfg.silent)
	local count = sync_all(state.nb)
	notify.info(string.format("Reset complete! Re-indexed %d notes.", count))
end

--- Scans the active notebook directory, parses each markdown file with
--- parser.lua, and upserts all notes into the database.
function M.sync()
	state.ensure_active()

	local nb = state.nb
	if not nb then
		notify.error("No active notebook to sync", state.cfg.silent)
		return
	end

	local uv = vim.uv or vim.loop

	hooks.fire("pre_sync", { notebook = { id = nb.id, title = nb.title, root_path = nb.root_path } })
	notify.info("Syncing notebook: " .. nb.title, state.cfg.silent)
	local start_time = uv.hrtime()

	local count = sync_all(nb)

	local duration = (uv.hrtime() - start_time) / 1e6
	notify.info(string.format("Sync complete! Indexed %d files in %.2fms", count, duration))
	hooks.fire(
		"post_sync",
		{ notebook = { id = nb.id, title = nb.title, root_path = nb.root_path }, count = count, duration = duration }
	)
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
	local note = parser.parse(lines) --[[@as BookwyrmNote]]
	note.relative_path = rel_path
	note.title = vim.fn.fnamemodify(path, ":t:r")
	note.fsize = vim.fn.getfsize(path)
	note.mtime = vim.fn.getftime(path)

	state.get_conn().notes:upsert_note(nb.id, note)
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
	local note = parser.parse(lines) --[[@as BookwyrmNote]]
	note.relative_path = rel_path
	note.title = vim.fn.fnamemodify(path, ":t:r")
	note.fsize = vim.fn.getfsize(path)
	note.mtime = vim.fn.getftime(path)

	state.get_conn().notes:upsert_note(nb.id, note)
end

return M

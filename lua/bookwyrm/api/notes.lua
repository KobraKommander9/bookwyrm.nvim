--- @class BookwyrmNoteAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

--- @param extra table<string, any>? # Extra variables
local function get_template_variables(extra)
	local vars = {
		date = os.date("%Y-%m-%d"),
		datetime = os.date("%Y-%m-%d %H:%M"),
		line = vim.fn.line("#"), -- last line number in previous file
		notebook = state.nb and state.nb.title or "Unknown",
		path = vim.fn.expand("#:p"), -- full path of the previous file
		relpath = vim.fn.expand("#:~"), -- path of previous file relative to home
		source = vim.fn.expand("#:t"), -- name of the previous file
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

local function parse_template(str, vars)
	return (str:gsub("{{%s*(.-)%s*}}", function(key)
		return vars[key] or ("{{" .. key .. "}}")
	end))
end

--- @class BookwyrmNoteAPI.CaptureNoteOpts
--- @field path string? # The path to the new note. Defaults to (template or %Y-%m-%d_%H-%M-%S)
--- @field tname string? # The note template name

--- Captures the provided text into a new note using the specified template.
---
--- @param lines string[] # The lines to capture
--- @param opts BookwyrmNoteAPI.CaptureNoteOpts? # Capture options
--- @return BookwyrmNote?
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
	path = paths.normalize_fname(path)

	local rel_path = paths.normalize_fname(parse_template(path, vars)) .. ".md"
	local full_path = state.nb.root_path .. "/" .. rel_path
	paths.ensure_dir(vim.fn.fnamemodify(full_path, ":h"))

	local content = { "" }
	table.insert(content, template.header and parse_template(template.header, vars) or "---\n")

	for _, line in ipairs(lines) do
		local formatted = (template.prefix and parse_template(template.prefix, vars) or "") .. line
		table.insert(content, formatted)
	end

	local f = io.open(full_path, "a")
	if f then
		f:write(table.concat(content, "\n") .. "\n")
		f:close()
	-- TODO: notify and resync the specific file in db
	else
		notify.error("Failed to open new note: " .. full_path, state.cfg.silent)
	end
end

--- Syncs the file with the db.
---
--- @param path string? # The path to the file, defualts to the current file.
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

	local root = nb.root_path
	if not root:match("/$") then
		root = root .. "/"
	end
	local rel_path = path:sub(#root + 1)
end

return M

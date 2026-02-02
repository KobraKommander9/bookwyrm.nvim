--- @class BookwyrmNoteAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

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
	local path = template.path or opts.path or "%Y-%m-%d_%H-%M-%S"

	local rel_path = os.date(path)
	local full_path = state.nb.root_path .. "/" .. rel_path
	paths.ensure_dir(vim.fn.fnamemodify(full_path, ":h"))

	local content = { "" }
	if template.header then
		table.insert(content, os.date(template.header))
	end

	for _, line in ipairs(lines) do
		local formatted = (template.prefix or "") .. line
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

return M

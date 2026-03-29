--- @class BookwyrmPickersAPI
local M = {}

local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

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

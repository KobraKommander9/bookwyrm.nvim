--- Link resolver: translates [[wiki-style links]] to absolute file paths.
---
--- The public `resolve` function depends on plugin state. For unit testing,
--- use `resolve_with_conn` directly, passing mock DB and notebook data.

--- @class BookwyrmResolverAPI
local M = {}

--- Resolves a link text to an absolute file path.
---
--- Checks the `aliases` table first (case-insensitive), then the `notes`
--- table by title (case-insensitive). Returns the first match found.
---
--- @param link_text string      # The raw text inside [[...]], without brackets
--- @param db        BookwyrmDB  # A BookwyrmDB instance
--- @param nb_id     integer     # The notebook id to search within
--- @param root_path string      # The notebook root path (no trailing slash)
--- @return string?              # Absolute file path, or nil if not found
function M.resolve_with_conn(link_text, db, nb_id, root_path)
	if not link_text or link_text == "" then
		return nil
	end
	if not db or not nb_id or not root_path then
		return nil
	end

	-- Strip anchor fragment (e.g. "Note#section" → "Note") and display alias
	local title = link_text:match("^([^#|]+)") or link_text
	local lower = title:lower()

	-- 1. Check aliases table first (case-insensitive)
	local alias_path = db.notes:resolve_by_alias(nb_id, lower)
	if alias_path then
		return root_path .. "/" .. alias_path
	end

	-- 2. Fall back to notes table by title (case-insensitive)
	local note_path = db.notes:resolve_by_title(nb_id, lower)
	if note_path then
		return root_path .. "/" .. note_path
	end

	return nil
end

--- Resolves a wiki link against the active notebook using plugin state.
---
--- @param link_text string # The raw text inside [[...]], without brackets
--- @return string?         # Absolute file path, or nil if not found
function M.resolve(link_text)
	local state = require("bookwyrm.state")

	if not state.nb then
		return nil
	end

	local db = state.get_conn()
	if not db then
		return nil
	end

	return M.resolve_with_conn(link_text, db, state.nb.id, state.nb.root_path)
end

--- Extracts the [[...]] link text at the given column on a line.
---
--- Returns the content between [[ and ]], or nil if the column is not inside
--- a wiki link.
---
--- @param line string   # The full line of text
--- @param col  integer  # 1-based column position
--- @return string?      # Link text (without brackets), or nil
function M.link_at(line, col)
	-- Iterate over all [[...]] spans on the line
	local pos = 1
	while true do
		local s, text, e = line:match("()%[%[(.-)%]%]()", pos)
		if not s then
			break
		end
		-- col is within the span (inclusive of brackets)
		if col >= s and col < e then
			return text
		end
		pos = e
	end
	return nil
end

--- Opens the target of the [[...]] link under the cursor.
---
--- If the cursor is not on a wiki link, falls back to the built-in `gd`.
--- If no note matches, emits a warning notification.
function M.goto_definition()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- convert to 1-based

	local link_text = M.link_at(line, col)
	if not link_text then
		-- Fall back to the built-in gd
		vim.cmd("normal! gd")
		return
	end

	-- Strip display alias (e.g. "Note|Display" → "Note")
	local target = link_text:match("^([^|]+)") or link_text

	local path = M.resolve(target)
	if path then
		vim.cmd.edit(vim.fn.fnameescape(path))
	else
		local notify = require("bookwyrm.util.notify")
		notify.warn("No note found for link: [[" .. target .. "]]")
	end
end

return M

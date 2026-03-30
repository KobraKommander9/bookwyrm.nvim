--- Computed metadata virtual-text header rendered at the top of notebook files.
---
--- Displays: Total Tasks · Done · Backlinks
--- Uses virt_lines so line numbers are not shifted.

local M = {}

local state = require("bookwyrm.state")

--- Returns { total_tasks, done_tasks, backlink_count } for a given note id,
--- or nil if the DB is unavailable.
---
--- @param note_id integer
--- @return integer, integer, integer
local function fetch_counts(note_id)
	local db = state.get_conn()
	if not db then
		return 0, 0, 0
	end

	local conn = db.conn

	local task_rows = conn:eval(
		"SELECT COUNT(*) AS n FROM tasks WHERE note_id = :id",
		{ id = note_id }
	)
	local done_rows = conn:eval(
		"SELECT COUNT(*) AS n FROM tasks WHERE note_id = :id AND status = 1",
		{ id = note_id }
	)
	local bl_rows = conn:eval(
		"SELECT COUNT(*) AS n FROM links WHERE target_note_id = :id",
		{ id = note_id }
	)

	local total = (task_rows and task_rows[1] and task_rows[1].n) or 0
	local done = (done_rows and done_rows[1] and done_rows[1].n) or 0
	local backlinks = (bl_rows and bl_rows[1] and bl_rows[1].n) or 0

	return total, done, backlinks
end

--- Renders computed metadata virtual text at the top of the buffer.
---
--- @param buf integer
--- @param ns integer  # extmark namespace
--- @param nb BookwyrmBook
function M.render(buf, ns, nb)
	local path = vim.api.nvim_buf_get_name(buf)
	if not path or path == "" then
		return
	end

	local rel = path:sub(#nb.root_path + 2) -- strip "root_path/"

	local db = state.get_conn()
	if not db then
		return
	end

	local note = db.notes:get_by_path(nb.id, rel)
	if not note then
		return
	end

	local total, done, backlinks = fetch_counts(note.id)

	local text = string.format(
		"  Tasks: %d  Done: %d  Backlinks: %d",
		total,
		done,
		backlinks
	)

	vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
		virt_lines = { { { text, "BookwyrmMeta" } } },
		virt_lines_above = true,
	})
end

return M

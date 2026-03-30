--- Back-reference decorations:
---   • eol virtual text on line 0 showing backlink count (← N)
---   • Sign on line 0 for notes with no backlinks (orphan indicator)

local M = {}

local state = require("bookwyrm.state")

local SIGN_NAME = "BookwyrmOrphanSign"
local SIGN_TEXT = "◌"

--- Ensures the orphan sign is defined (idempotent).
local function ensure_sign()
	if vim.fn.sign_getdefined(SIGN_NAME)[1] then
		return
	end
	vim.fn.sign_define(SIGN_NAME, {
		text = SIGN_TEXT,
		texthl = "BookwyrmOrphan",
	})
end

--- @param buf integer
--- @param ns  integer
--- @param nb  BookwyrmBook
function M.render(buf, ns, nb)
	ensure_sign()

	local path = vim.api.nvim_buf_get_name(buf)
	if not path or path == "" then
		return
	end

	local rel = path:sub(#nb.root_path + 2)

	local db = state.get_conn()
	if not db then
		return
	end

	local note = db.notes:get_by_path(nb.id, rel)
	if not note then
		return
	end

	local rows = db.conn:eval(
		"SELECT COUNT(*) AS n FROM links WHERE target_note_id = :id",
		{ id = note.id }
	)
	local count = (rows and rows[1] and rows[1].n) or 0

	if count > 0 then
		-- Show backlink count as eol virtual text on line 0
		vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
			virt_text = { { string.format("← %d", count), "BookwyrmBacklinkCount" } },
			virt_text_pos = "eol",
		})
	else
		-- Place orphan sign on line 1 (sign_place uses 1-indexed lines)
		vim.fn.sign_place(0, "bookwyrm_orphan", SIGN_NAME, buf, { lnum = 1 })
	end
end

return M

--- Link decorations: concealment of [[ / ]], underline, broken vs valid colours.
---
--- Respects vim.o.conceallevel — when it is 0 the [[ / ]] brackets remain visible.

local M = {}

local state = require("bookwyrm.state")

--- Builds a set of note titles / relative-paths that exist in the DB for quick
--- validity checks.  Returns an empty table when the DB is unavailable.
---
--- @param nb_id integer
--- @return table<string, boolean>  # lower-cased title → true
local function build_valid_set(nb_id)
	local db = state.get_conn()
	if not db then
		return {}
	end

	local rows = db.conn:eval(
		"SELECT lower(title) AS t, lower(relative_path) AS p FROM notes WHERE notebook_id = :nb_id",
		{ nb_id = nb_id }
	)

	local valid = {}
	for _, row in ipairs(rows or {}) do
		if row.t then
			valid[row.t] = true
		end
		if row.p then
			valid[row.p] = true
			-- also without the .md suffix
			valid[row.p:gsub("%.md$", "")] = true
		end
	end
	return valid
end

--- Renders link decorations on buf.
---
--- @param buf   integer
--- @param ns    integer   # extmark namespace
--- @param nb    BookwyrmBook
function M.render(buf, ns, nb)
	local conceal = vim.o.conceallevel > 0

	local valid_set = build_valid_set(nb.id)

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	for lnum, line in ipairs(lines) do
		local row = lnum - 1 -- 0-indexed

		-- Iterate over all [[...]] occurrences
		local pos = 1
		while true do
			local link_start, raw_end = line:find("%[%[.-%]%]", pos)
			if not link_start then
				break
			end

			local raw_link = line:sub(link_start + 2, raw_end - 2)
			local target = raw_link:match("([^|#]+)") or raw_link
			target = target:match("^%s*(.-)%s*$") -- trim

			local is_valid = valid_set[target:lower()] ~= nil
			local link_hl = is_valid and "BookwyrmLinkValid" or "BookwyrmLinkBroken"

			-- Highlight the entire [[...]] span
			vim.api.nvim_buf_set_extmark(buf, ns, row, link_start - 1, {
				end_col = raw_end,
				hl_group = link_hl,
				priority = 100,
			})

			-- Conceal [[ (2 chars)
			if conceal then
				vim.api.nvim_buf_set_extmark(buf, ns, row, link_start - 1, {
					end_col = link_start + 1,
					conceal = "",
				})

				-- Conceal ]] (2 chars at end)
				vim.api.nvim_buf_set_extmark(buf, ns, row, raw_end - 2, {
					end_col = raw_end,
					conceal = "",
				})
			end

			pos = raw_end + 1
		end
	end
end

return M

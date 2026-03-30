--- Frontmatter decorations: muted delimiters and bold/coloured YAML keys.

local M = {}

-- Keys that receive the BookwyrmFrontmatterKey highlight
local KEY_PATTERN = "^([%w_%-]+)%s*:"

--- Renders frontmatter highlight decorations.
---
--- @param buf integer
--- @param ns  integer  # extmark namespace
function M.render(buf, ns)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	if lines[1] ~= "---" then
		return
	end

	local in_fm = true
	local delim_count = 0

	for lnum, line in ipairs(lines) do
		local row = lnum - 1

		if line == "---" then
			-- Highlight the delimiter
			vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
				end_col = #line,
				hl_group = "BookwyrmFrontmatterDelim",
				priority = 90,
			})

			delim_count = delim_count + 1
			if delim_count == 2 then
				in_fm = false
			end
		elseif in_fm then
			-- Highlight the key portion (before the colon)
			local key = line:match(KEY_PATTERN)
			if key then
				vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
					end_col = #key,
					hl_group = "BookwyrmFrontmatterKey",
					priority = 90,
				})
			end
		end
	end
end

return M

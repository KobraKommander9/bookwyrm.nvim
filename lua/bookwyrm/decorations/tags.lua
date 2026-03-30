--- Tag decorations: pill/badge background highlight on #tag tokens.
---
--- Only decorates inline tags in the note body (not frontmatter).

local M = {}

--- Renders tag highlights on buf.
---
--- @param buf integer
--- @param ns  integer  # extmark namespace
function M.render(buf, ns)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Skip frontmatter
	local start_lnum = 1
	if lines[1] == "---" then
		for i = 2, #lines do
			if lines[i] == "---" then
				start_lnum = i + 1
				break
			end
		end
	end

	for lnum = start_lnum, #lines do
		local line = lines[lnum]
		local row = lnum - 1

		-- Skip inside code fences
		if line:match("^%s*```") then
			-- handled by codeblocks module; skip this line
		end

		local pos = 1
		while true do
			-- Match a #tag that is preceded by whitespace/start or punctuation
			local tag_start, tag_end = line:find("#[%w_%-]+", pos)
			if not tag_start then
				break
			end

			-- Ensure it's not inside a [[link]]
			local prefix = line:sub(1, tag_start - 1)
			local open_brackets = select(2, prefix:gsub("%[%[", ""))
			local close_brackets = select(2, prefix:gsub("%]%]", ""))
			local inside_link = open_brackets > close_brackets

			if not inside_link then
				vim.api.nvim_buf_set_extmark(buf, ns, row, tag_start - 1, {
					end_col = tag_end,
					hl_group = "BookwyrmTag",
					priority = 80,
				})
			end

			pos = tag_end + 1
		end
	end
end

return M

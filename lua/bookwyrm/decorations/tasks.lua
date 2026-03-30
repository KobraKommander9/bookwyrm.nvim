--- Task decorations: strikethrough highlight on completed task lines (- [x]).

local M = {}

--- @param buf integer
--- @param ns  integer
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

		-- Match completed task: - [x] or - [X]
		if line:match("^%s*%-%s*%[[xX]%]") then
			vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
				end_col = #line,
				hl_group = "BookwyrmTaskDone",
				priority = 100,
			})
		end
	end
end

return M

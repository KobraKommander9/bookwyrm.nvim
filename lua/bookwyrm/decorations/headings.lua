--- Heading decorations:
---   • Gradient highlight per level (BookwyrmH1–H6)
---   • Concealed leading # symbols, replaced with level icons
---   • virt_lines horizontal rule rendered below H1

local M = {}

local LEVEL_HL = {
	"BookwyrmH1",
	"BookwyrmH2",
	"BookwyrmH3",
	"BookwyrmH4",
	"BookwyrmH5",
	"BookwyrmH6",
}

--- Icons used to replace the concealed # prefix (one per level).
local LEVEL_ICONS = {
	"󰉫 ", -- H1
	"󰉬 ", -- H2
	"󰉭 ", -- H3
	"󰉮 ", -- H4
	"󰉯 ", -- H5
	"󰉰 ", -- H6
}

--- Horizontal rule rendered as a virt_line below H1.
local H1_RULE_CHAR = "─"
local H1_RULE_WIDTH = 60

--- Renders heading decorations.
---
--- @param buf integer
--- @param ns  integer  # extmark namespace
function M.render(buf, ns)
	local conceal = vim.o.conceallevel > 0

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

		-- Match heading: optional leading spaces, then 1-6 # followed by space
		local hashes, rest = line:match("^(#+)%s+(.*)")
		if hashes and #hashes <= 6 then
			local level = #hashes
			local hl = LEVEL_HL[level]

			-- Highlight the full line
			vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
				end_col = #line,
				hl_group = hl,
				priority = 110,
			})

			-- Conceal the # prefix and space, replace with icon
			if conceal then
				local icon = LEVEL_ICONS[level] or "# "
				vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
					end_col = level + 1, -- hashes + one space
					conceal = icon,
				})
			end

			-- Virtual horizontal rule below H1
			if level == 1 then
				local rule = string.rep(H1_RULE_CHAR, H1_RULE_WIDTH)
				vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
					virt_lines = { { { rule, "BookwyrmH1Rule" } } },
					virt_lines_above = false,
				})
			end
		end
	end
end

return M

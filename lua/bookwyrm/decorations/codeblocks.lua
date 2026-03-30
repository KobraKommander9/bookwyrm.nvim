--- Code block decorations:
---   • Background shade across the full code block region (BookwyrmCodeBlock)
---   • Language icon as virtual text on the opening fence line

local M = {}

--- Maps common language identifiers to Nerd Font icons.
local LANG_ICONS = {
	lua = " ",
	python = " ",
	javascript = " ",
	typescript = " ",
	rust = " ",
	go = " ",
	bash = " ",
	sh = " ",
	zsh = " ",
	css = " ",
	html = " ",
	json = " ",
	yaml = " ",
	toml = " ",
	sql = " ",
	vim = " ",
	c = " ",
	cpp = " ",
	java = " ",
	ruby = " ",
	php = " ",
}

local DEFAULT_ICON = " "

--- @param buf integer
--- @param ns  integer
function M.render(buf, ns)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local fence_start = nil
	local fence_lang = nil

	for lnum, line in ipairs(lines) do
		local row = lnum - 1

		local lang = line:match("^%s*```(%S*)")
		if lang ~= nil and fence_start == nil then
			-- Opening fence
			fence_start = row
			fence_lang = (lang ~= "") and lang or nil

			local icon = (fence_lang and (LANG_ICONS[fence_lang:lower()] or DEFAULT_ICON)) or DEFAULT_ICON
			local label = fence_lang and (icon .. fence_lang) or icon

			vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
				virt_text = { { label, "BookwyrmCodeLang" } },
				virt_text_pos = "eol",
			})
		elseif line:match("^%s*```%s*$") and fence_start ~= nil then
			-- Closing fence — shade the entire block including fence lines
			for r = fence_start, row do
				vim.api.nvim_buf_set_extmark(buf, ns, r, 0, {
					end_col = 0,
					end_row = r + 1,
					hl_group = "BookwyrmCodeBlock",
					hl_eol = true,
					priority = 50,
				})
			end

			fence_start = nil
			fence_lang = nil
		end
	end
end

return M

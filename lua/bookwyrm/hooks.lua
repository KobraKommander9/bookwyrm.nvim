local M = {}

--- @class BookwyrmAPI
local api = require("bookwyrm.api")
local state = require("bookwyrm.state")

function M.setup_context_switcher()
	vim.api.nvim_create_autocmd("BufEnter", {
		group = vim.api.nvim_create_augroup("BookwyrmContext", { clear = true }),
		pattern = "*.md",
		callback = function()
			local nb = api.get_notebook_by_path()
			state.set_active(nb)
		end,
	})
end

return M

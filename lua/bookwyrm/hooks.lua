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

--- Sets up a buffer-local `gd` keymap for markdown files that belong to the
--- active notebook. The keymap resolves [[wiki links]] under the cursor; if
--- the cursor is not on a link it falls back to the built-in `gd`.
function M.setup_navigation()
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = vim.api.nvim_create_augroup("BookwyrmNavigation", { clear = true }),
		pattern = "*.md",
		callback = function(ev)
			local path = vim.api.nvim_buf_get_name(ev.buf)
			if not path or path == "" then
				return
			end

			-- Only set the keymap when the file lives inside a registered notebook
			local nb = api.get_notebook_by_path(path)
			if not nb then
				return
			end

			local resolver = require("bookwyrm.api.resolver")
			vim.keymap.set("n", "gd", resolver.goto_definition, {
				buffer = ev.buf,
				desc = "Bookwyrm: go to [[wiki link]] definition",
				silent = true,
			})
		end,
	})
end

return M

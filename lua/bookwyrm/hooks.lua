local M = {}

--- @class BookwyrmAPI
local api = require("bookwyrm.api")
local state = require("bookwyrm.state")

--- Registers (or re-registers) the BufWritePost watchdog for the active notebook.
---
--- Creates a dedicated `BookwyrmWatchdog` augroup (clearing any previous registration)
--- and registers a `BufWritePost` autocmd scoped to the active notebook's markdown files.
--- If no notebook is active the augroup is still cleared but no autocmd is added.
function M.setup_watchdog()
	local group = vim.api.nvim_create_augroup("BookwyrmWatchdog", { clear = true })

	if not state.nb then
		return
	end

	local nb = state.nb

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = nb.root_path .. "/*.md",
		callback = function(ev)
			local path = vim.api.nvim_buf_get_name(ev.buf)
			api.sync_buffer(ev.buf)
			api.fire("post_sync", { path = path })
		end,
	})
end

function M.setup_context_switcher()
	vim.api.nvim_create_autocmd("BufEnter", {
		group = vim.api.nvim_create_augroup("BookwyrmContext", { clear = true }),
		pattern = "*.md",
		callback = function()
			local nb = api.get_notebook_by_path()
			local prev_id = state.nb and state.nb.id
			state.set_active(nb)
			if state.nb and state.nb.id ~= prev_id then
				M.setup_watchdog()
			end
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

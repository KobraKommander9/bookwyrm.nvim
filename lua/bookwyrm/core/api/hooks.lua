--- @class BookwyrmHooksAPI
local M = {}

local state = require("bookwyrm.core.state")

--- @param bufnr integer
--- @return boolean
local function is_markdown(bufnr)
	return vim.bo[bufnr].filetype == "markdown"
end

--- @param path string
--- @return BookwyrmBook?
local function get_notebook_for_path(path)
	if not state.db then
		return nil
	end

	local nbs = state.db:list()
	if not nbs or #nbs == 0 then
		return nil
	end

	local best_match = nil
	local longest_path = -1

	for _, nb in ipairs(nbs) do
		if vim.startswith(path, nb.path) then
			if #nb.path > longest_path then
				longest_path = #nb.path
				best_match = nb
			end
		end
	end

	return best_match
end

--- Checks if the saved file belongs in a notebook and will write it to the
--- appropriate notebook.
function M.on_save()
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" or not is_markdown(0) then
		return
	end

	local nb = get_notebook_for_path(path)
	if not nb then
		return
	end

	if not state.get_active_id() then
		state.open_notebook(nb)
	end

	-- TODO: save note
end

return M

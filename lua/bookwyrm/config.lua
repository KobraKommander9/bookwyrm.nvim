local M = {}

local defaults = {
	db = vim.fn.stdpath("data") .. "/bookwyrm.db",
}

M.options = vim.deepcopy(defaults)

return M

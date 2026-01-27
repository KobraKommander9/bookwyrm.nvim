local M = {}

function M.error(msg)
	vim.notify(msg, vim.log.levels.ERROR, {
		title = "Bookwyrm.nvim",
	})
end

return M

local M = {}

function M.error(msg)
	vim.notify(msg, vim.log.levels.ERROR, {
		title = "Bookwyrm.nvim",
	})
end

function M.info(msg)
	vim.notify(msg, vim.log.levels.INFO, {
		title = "Bookwyrm.nvim",
	})
end

return M

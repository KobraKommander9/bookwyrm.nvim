local M = {}

local function notify(msg, level, silent)
	if silent then
		return
	end

	vim.notify(msg, level, {
		title = "Bookwyrm.nvim",
	})
end

function M.error(msg, silent)
	notify(msg, vim.log.levels.ERROR, silent)
end

function M.info(msg, silent)
	notify(msg, vim.log.levels.INFO, silent)
end

function M.warn(msg, silent)
	notify(msg, vim.log.levels.WARN, silent)
end

return M

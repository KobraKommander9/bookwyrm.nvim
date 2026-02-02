local M = {}

local function notify(msg, level, silent)
	if silent == true then
		return
	end

	vim.notify(msg, level, {
		title = "Bookwyrm.nvim",
	})
end

--- @param msg string
--- @param silent boolean?
function M.error(msg, silent)
	notify(msg, vim.log.levels.ERROR, silent)
end

--- @param msg string
--- @param silent boolean?
function M.info(msg, silent)
	notify(msg, vim.log.levels.INFO, silent)
end

--- @param msg string
--- @param silent boolean?
function M.warn(msg, silent)
	notify(msg, vim.log.levels.WARN, silent)
end

return M

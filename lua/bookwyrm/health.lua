local M = {}

function M.check()
	vim.health.start("bookwyrm.nvim report")

	if pcall(require, "sqlite") then
		vim.health.ok("sqlite.lua is installed")
	else
		vim.health.error("sqlite.lua is missing")
	end

	-- if vim.fn.executable("rg") == 1 then
	-- 	vim.health.ok("ripgrep is installed")
	-- else
	-- 	vim.health.warn("ripgrep not found; full-text search will be slow")
	-- end
end

return M

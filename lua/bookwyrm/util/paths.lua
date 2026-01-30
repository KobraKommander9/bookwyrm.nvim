local M = {}

--- Ensures the directory exists (if directory), making it if it doesn't.
---
--- @param path string # The path to check
function M.ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

--- Normalizes the path by removing trailing slashes and expanding ~
---
--- @param path string # The path to normalize
--- @return string
function M.normalize(path)
	path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
	return vim.fs.normalize(path)
end

return M

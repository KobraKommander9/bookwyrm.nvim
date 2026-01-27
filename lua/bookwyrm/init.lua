local M = {}

function M.setup(opts)
	local cfg = require("bookwyrm.config")
	cfg.options = vim.tbl_deep_extend("force", cfg.options, opts or {})
end

return M

local M = {}

M.api = require("bookwyrm.api")

function M.setup(opts)
	require("bookwyrm.config").setup(opts)
end

return M

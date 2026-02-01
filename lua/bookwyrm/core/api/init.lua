local M = {}

local journal = require("bookwyrm.core.api.journal")
local hooks = require("bookwyrm.core.api.hooks")

M = vim.tbl_extend("force", M, journal, hooks)

return M

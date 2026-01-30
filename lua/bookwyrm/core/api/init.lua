--- @class BookwyrmAPI: BookwyrmNotebookAPI, BookwyrmJournalAPI, BookwyrmHooksAPI
local M = {}

local notebook = require("bookwyrm.core.api.notebook")
local journal = require("bookwyrm.core.api.journal")
local hooks = require("bookwyrm.core.api.hooks")

M = vim.tbl_extend("force", M, notebook, journal, hooks)

return M

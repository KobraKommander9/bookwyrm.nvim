--- @class BookwyrmAPI: BookwyrmNotebookAPI, BookwyrmNoteAPI, BookwyrmHooksAPI
local M = {}

local notebook = require("bookwyrm.api.notebook")
local note = require("bookwyrm.api.note")
local hooks = require("bookwyrm.api.hooks")

M = vim.tbl_extend("force", M, notebook, note, hooks)

return M

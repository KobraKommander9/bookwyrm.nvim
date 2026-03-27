--- @class BookwyrmAPI: BookwyrmNotebookAPI, BookwyrmNoteAPI, BookwyrmHooksAPI
local M = {}

local hooks = require("bookwyrm.api.hooks")
local notebooks = require("bookwyrm.api.notebooks")
local notes = require("bookwyrm.api.notes")

M = vim.tbl_extend("force", M, hooks, notebooks, notes)

return M

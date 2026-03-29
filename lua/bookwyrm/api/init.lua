--- @class BookwyrmAPI: BookwyrmNotebookAPI, BookwyrmNoteAPI, BookwyrmHooksAPI, BookwyrmPickersAPI
local M = {}

local hooks = require("bookwyrm.api.hooks")
local notebooks = require("bookwyrm.api.notebooks")
local notes = require("bookwyrm.api.notes")
local pickers = require("bookwyrm.api.pickers")

M = vim.tbl_extend("force", M, hooks, notebooks, notes, pickers)

return M

local M = {}

local DB = require("bookwyrm.db")
local Paths = require("bookwyrm.paths")
local Notify = require("bookwyrm.notify")

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

--- Returns all the registered notebooks.
---
--- @return BookwyrmBook[]
function M.get_notebook_list()
	if not DB then
		return {}
	end

	return DB.get_notebooks()
end

--- @class Bookwyrm.api.RegisterOpts
--- @field path string? # The path to the notebook directory (defaults to CWD)
--- @field title string? # Friendly name for the notebook (defaults to folder name)
--- @field auto_scan boolean? # Whether to scan files immediately after registration (defaults to true)
--- @field silent boolean? # If true will silence notifications (defaults to false)

--- Registers a new notebook.
---
--- @param opts Bookwyrm.api.RegisterOpts # Registration opts
function M.register_notebook(opts)
	opts = opts or {}

	if not DB then
		Notify.warn("DB not registered", opts.silent)
		return
	end

	local path = Paths.normalize(opts.path or vim.fn.getcwd())
	local title = opts.title and (opts.title ~= "" and opts.title) or vim.fn.fnamemodify(path, ":t")

	DB.register_notebook(path, title, opts.silent)
end

--- Selects a notebook and makes it active.
---
--- @param id integer # The id of the notebook
function M.select_notebook(id)
	if not DB then
		return
	end

	DB.switch_to_notebook(id)
end

return M

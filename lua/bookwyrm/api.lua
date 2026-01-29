local M = {}

local DB = require("bookwyrm.db")
local Paths = require("bookwyrm.paths")
local Notify = require("bookwyrm.notify")

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

--- Deletes the notebook. This just removes the notebook from the registry,
--- does not affect the filesystem.
---
--- @param id integer? # The id of the notebook to delete (defaults to active).
function M.delete_notebook(id)
	if not DB then
		Notify.warn("DB not registered")
		return
	end

	DB.delete_notebook(id)
end

--- Returns the active notebook title, if any.
function M.get_active_title()
	if not DB then
		return nil
	end

	return DB.get_active_title()
end

--- Returns all the registered notebooks.
---
--- @return BookwyrmBook[]
function M.get_notebook_list()
	if not DB then
		return {}
	end

	return DB.get_notebooks()
end

--- Loads the default notebook.
function M.load_default_notebook()
	if not DB then
		return
	end

	DB.load_active_notebook()
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

--- Renames the notebook to the given title.
---
--- @param title string # The new title of the notebook
--- @param id integer? # The id of the notebook (defaults to active)
function M.rename_notebook(title, id)
	if not DB then
		Notify.warn("DB not registered")
		return
	end

	DB.rename_notebook(title, id)
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

--- Selects a notebook and makes it active.
---
--- @param id integer? # The id of the notebook, defaults to active
function M.set_default_notebook(id)
	if not DB then
		return
	end

	DB.set_default_notebook(id)
end

return M

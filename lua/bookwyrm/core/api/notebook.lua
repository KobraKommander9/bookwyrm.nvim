--- @class BookwyrmNotebookAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local state = require("bookwyrm.core.state")

--- Deletes the notebook. This just removes the notebook from the registry,
--- does not affect the filesystem.
---
--- @param id integer? # The id of the notebook to delete (defaults to active).
function M.delete_notebook(id)
	if not state.db then
		return
	end

	notify.error("delete_notebook unimplemented")
end

--- Returns the active notebook, if any.
---
--- @return BookwyrmBook?
function M.get_active_notebook()
	return state.nb and state.nb.book
end

--- Lists notebooks.
---
--- @return BookwyrmBook[]
function M.list_notebooks()
	if not state.db then
		return {}
	end

	notify.error("list_notebooks unimplemented")

	return {}
end

--- Loads the default notebook, if one is set.
function M.load_default_notebook()
	if not state.db then
		return
	end

	notify.error("load_default_notebook unimplemented")
end

--- @class BookwyrmNotebookAPI.RegisterOpts
--- @field path string? The path to the notebook directory (defaults to CWD)
--- @field title string? The title of the notebook (defaults to folder name)

--- Registers the notebook for use with bookwyrm.
---
--- @param opts BookwyrmNotebookAPI.RegisterOpts
function M.register_notebook(opts)
	if not state.db then
		return
	end

	notify.error("register_notebook unimplemented")
end

--- Renames the notebook.
---
--- @param title string # The new title
--- @param id integer? # The id of the notebook to rename, defaults to active.
function M.rename_notebook(title, id)
	if not state.db then
		return
	end

	notify.error("rename_notebook unimplemented")
end

--- Sets the default notebook.
---
--- @param id integer? # The id of the notebook, defaults to active
function M.set_default_notebook(id)
	if not state.db then
		return
	end

	notify.error("set_default_notebook unimplemented")
end

--- Switches to the specified notebook. Noop if already selected.
---
--- @param id integer # The id of the notebook to switch to
function M.switch_to_notebook(id)
	if not state.db then
		return
	end

	notify.error("switch_to_notebook unimplemented")
end

--- @class BookwyrmNotebookAPI.UnregisterNotebookOpts
--- @field id integer? # The id of the notebook to unregister (defaults to active).
--- @field delete boolean? # If true will remove the sqlite db

--- Unregisters the notebook and optionally deletes the sqlite db.
---
--- @param opts BookwyrmNotebookAPI.UnregisterNotebookOpts
function M.unregister_notebook(opts)
	if not state.db then
		return
	end

	notify.error("unregister_notebook unimplemented")
end

return M

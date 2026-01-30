--- @class BookwyrmNotebookAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local state = require("bookwyrm.core.state")

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

	return state.db:list()
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
	opts = opts or {}

	if not state.db then
		return
	end

	local target_id = opts.id
	if not target_id then
		if state.nb then
			target_id = state.nb.book.id
		else
			notify.warn("No notebook id provided and no notebook currently active", state.cfg.silent)
			return
		end
	end

	if state.nb and state.nb.book.id == target_id then
		state.nb:close()
		state.nb = nil
	end

	local nb = state.db:delete(target_id)
	if not nb or not opts.delete then
		return
	end

	local success, err = os.remove(nb.db_path)
	if not success then
		notify.warn(
			"unregistered notebook but could not delete file (" .. nb.db_path .. ") for: " .. tostring(err),
			state.cfg.silent
		)
	else
		notify.info("deleted notebook database: " .. nb.title, state.cfg.silent)
	end
end

return M

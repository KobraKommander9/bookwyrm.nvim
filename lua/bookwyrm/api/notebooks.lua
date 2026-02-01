--- @class BookwyrmNotebookAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

--- Returns the active notebook, if any.
---
--- @param skip_db boolean? # If true won't check for default notebook in db if no active set
--- @return BookwyrmBook?
function M.get_active_notebook(skip_db)
	if skip_db or state.nb then
		return state.nb
	end

	local default = state.get_conn().notebooks:get_default()
	if default then
		state.nb = default
	end

	return state.nb
end

--- Lists notebooks.
---
--- @return BookwyrmBook[]
function M.list_notebooks()
	return state.get_conn().notebooks:list()
end

--- @class BookwyrmNotebookAPI.RegisterOpts
--- @field path string? # The path to the notebook directory (defaults to CWD)
--- @field priority integer? # The notebook priority (defaults to 0 -- highest)
--- @field title string? # The title of the notebook (defaults to folder name)

--- Registers a notebook for use with bookwyrm.
---
--- @param opts BookwyrmNotebookAPI.RegisterOpts?
--- @return BookwyrmBook? # The registered notebook, if successful
function M.register_notebook(opts)
	opts = opts or {}

	local path = paths.normalize(opts.path or vim.fn.getcwd())
	paths.ensure_dir(path)

	if vim.fn.isdirectory(path) == 0 then
		notify.error("path is not a valid directory: " .. path, state.cfg.silent)
		return nil
	end

	local nb = {
		priority = opts.priority or 0,
		root_path = path,
		title = opts.title or vim.fn.fnamemodify(path, ":t:r"),
	}

	local id = state.get_conn().notebooks:register(nb)
	if not id then
		notify.error("failed to register notebook", state.cfg.silent)
		return nil
	end

	nb.id = id

	state.nb = nb

	return nb
end

--- Renames the notebook.
---
--- @param title string # The new title
--- @param id integer? # The id of the notebook to rename, defaults to active.
function M.rename_notebook(title, id)
	id = id or state.get_active_id()
	if not id then
		notify.warn("no notebook to rename", state.cfg.silent)
		return nil
	end

	if not state.get_conn().notebooks:rename(title, id) then
		notify.error("failed to rename notebook", state.cfg.silent)
	else
		notify.info("successfully renamed notebook", state.cfg.silent)
	end
end

--- Sets the default notebook.
---
--- @param id integer? # The id of the notebook, defaults to active
function M.set_default_notebook(id)
	id = id or state.get_active_id()
	if not id then
		notify.warn("no notebook specified", state.cfg.silent)
		return
	end

	if not state.get_conn().notebooks:set_default(id) then
		notify.error("failed to set default notebook", state.cfg.silent)
	else
		notify.info("successfully set default notebook", state.cfg.silent)
	end
end

--- Switches to the specified notebook. Noop if already selected.
---
--- @param id integer # The id of the notebook to switch to
--- @return BookwyrmBook? # The opened notebook
function M.switch_to_notebook(id)
	if state.nb and state.nb.id == id then
		return state.nb
	end

	state.nb = state.get_conn().notebooks:get(id)

	return state.nb
end

--- Unregisters the notebook and optionally deletes the sqlite db.
---
--- @param id integer? # The id of the notebook to unregister (defaults to active).
function M.unregister_notebook(id)
	local target_id = id or state.get_active_id()
	if not target_id then
		notify.warn("No notebook id provided and no notebook currently active", state.cfg.silent)
		return
	end

	if state.get_active_id() == target_id then
		state.nb = nil
	end

	state.get_conn().notebooks:delete(target_id)
end

return M

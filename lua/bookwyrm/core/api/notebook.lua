--- @class BookwyrmNotebookAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local paths = require("bookwyrm.util.paths")
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

	local nb = state.db:get_default()
	if nb then
		state.open_notebook(nb)
	end
end

--- @class BookwyrmNotebookAPI.RegisterOpts
--- @field path string? The path to the notebook directory (defaults to CWD)
--- @field title string? The title of the notebook (defaults to folder name)

--- Registers a notebook for use with bookwyrm.
---
--- @param opts BookwyrmNotebookAPI.RegisterOpts?
--- @return BookwyrmBook? # The registered notebook, if successful
function M.register_notebook(opts)
	opts = opts or {}

	if not state.db then
		return
	end

	local path = paths.normalize(opts.path or vim.fn.getcwd())
	paths.ensure_dir(path)

	if vim.fn.isdirectory(path) == 0 then
		notify.error("path is not a valid directory: " .. path, state.cfg.silent)
		return nil
	end

	local title = opts.title or vim.fn.fnamemodify(path, ":t:r")
	local db_filename = title:gsub("%W", "_"):lower()
	local db_path = state.cfg.notebook_dir .. "/" .. db_filename .. ".sqlite"

	local count = 0
	local base_path = db_path

	while not vim.fn.filereadable(db_path) do
		count = count + 1
		if count >= 10 then
			notify.error("too many db files in directory", state.cfg.silent)
			return nil
		end

		db_path = base_path .. "(" .. count .. ").sqlite"
	end

	local nb = {
		db_path = db_path,
		path = path,
		title = title,
	}

	local id = state.db:register(nb)
	if not id then
		notify.error("failed to register notebook", state.cfg.silent)
		return nil
	end

	nb.id = id
	state.open_notebook(nb)

	return nb
end

--- Renames the notebook.
---
--- @param title string # The new title
--- @param id integer? # The id of the notebook to rename, defaults to active.
function M.rename_notebook(title, id)
	if not state.db then
		return
	end

	id = id or state.get_active_id()
	if not id then
		notify.warn("no notebook to rename", state.cfg.silent)
		return nil
	end

	if not state.db:rename(title, id) then
		notify.error("failed to rename notebook", state.cfg.silent)
	else
		notify.info("successfully renamed notebook", state.cfg.silent)
	end
end

--- Sets the default notebook.
---
--- @param id integer? # The id of the notebook, defaults to active
function M.set_default_notebook(id)
	if not state.db then
		return
	end

	id = id or state.get_active_id()
	if not id then
		notify.warn("no notebook specified", state.cfg.silent)
		return
	end

	if not state.db:set_default(id) then
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
	if not state.db then
		return nil
	end

	local nb = state.db:get(id)
	if not nb then
		return nil
	end

	state.open_notebook(nb)

	return nb
end

--- @class BookwyrmNotebookAPI.UnregisterNotebookOpts
--- @field id integer? # The id of the notebook to unregister (defaults to active).
--- @field delete boolean? # If true will remove the sqlite db

--- Unregisters the notebook and optionally deletes the sqlite db.
---
--- @param opts BookwyrmNotebookAPI.UnregisterNotebookOpts?
function M.unregister_notebook(opts)
	opts = opts or {}

	if not state.db then
		return
	end

	local target_id = opts.id or state.get_active_id()
	if not target_id then
		notify.warn("No notebook id provided and no notebook currently active", state.cfg.silent)
		return
	end

	if state.get_active_id() == target_id then
		state.close_notebook()
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

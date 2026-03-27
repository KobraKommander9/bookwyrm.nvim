--- @class BookwyrmNotebookAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.state")

--- Registers a new notebook and sets it as active.
---
--- @param name string # The display name for the notebook
--- @param path string # The path to the notebook directory
--- @return BookwyrmBook? # The registered notebook, if successful
function M.register(name, path)
	path = paths.normalize(path)
	paths.ensure_dir(path)

	if vim.fn.isdirectory(path) == 0 then
		notify.error("path is not a valid directory: " .. path, state.cfg.silent)
		return nil
	end

	local nb = {
		priority = 0,
		root_path = path,
		title = name,
	}

	local id = state.get_conn().notebooks:insert(nb)
	if not id then
		notify.error("failed to register notebook", state.cfg.silent)
		return nil
	end

	nb.id = id
	state.set_active(nb)

	return nb
end

--- Removes the active notebook record from the DB.
function M.delete()
	local id = state.get_active_id()
	if not id then
		notify.warn("no active notebook to delete", state.cfg.silent)
		return
	end

	state.nb = nil
	state.get_conn().notebooks:delete(id)
end

--- Returns all registered notebooks.
---
--- @return BookwyrmBook[]
function M.list()
	return state.get_conn().notebooks:list()
end

--- Updates the active notebook in state.
---
--- @param id integer # The id of the notebook to set as active
--- @return BookwyrmBook? # The newly active notebook
function M.set_active(id)
	if state.nb and state.nb.id == id then
		return state.nb
	end

	local nb = state.get_conn().notebooks:get_by_id(id)
	if not nb then
		notify.error("notebook not found: " .. tostring(id), state.cfg.silent)
		return nil
	end

	state.set_active(nb)

	return state.nb
end

return M

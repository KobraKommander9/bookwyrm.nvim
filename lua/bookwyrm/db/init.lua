local M = {}

local Cfg = require("bookwyrm.config")
local Notify = require("bookwyrm.notify")
local Paths = require("bookwyrm.paths")

local has_sqlite, sqlite = pcall(require, "sqlite.db")
if not has_sqlite then
	require("bookwyrm.notify").error("sqlite required")
	return nil
end

--- @type sqlite_db
local registry = nil
--- @type sqlite_db?
local active = nil
--- @type string?
local active_title = nil

-------------------------------------------------------------------------------
--- Init
-------------------------------------------------------------------------------

--- Initializes the registry db
---
--- @param path string # The path to the registry db
function M.init_registry(path)
	registry = sqlite:open(path)
	registry:create("notebooks", {
		active = { "integer", required = true },
		db_path = { "text", unique = true, required = true },
		id = { "integer", primary = true, autoincrement = true },
		path = { "text", unique = true, required = true },
		title = { "text", required = true },
	})
end

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

local function close_active()
	active:close()
	active = nil
	active_title = nil
end

--- Returns the active notebook title, if one is active. Can be used in
--- statuslines.
---
--- @return string?
function M.get_active_notebook()
	return active and active_title or nil
end

--- Find which notebook owns the current file
---
--- @param path string # The file path
--- @return BookwyrmBook?
function M.get_notebook_for_path(path)
	if not registry then
		return nil
	end

	local rows = registry:select("notebooks", { where = { active = 1 } })
	local best_match = nil
	local longest_path = -1

	for _, nb in ipairs(rows) do
		if vim.startswith(path, nb.path) then
			if #nb.path > longest_path then
				longest_path = #nb.path
				best_match = nb
			end
		end
	end

	return best_match
end

--- Provides a callback for swapping notebooks based on current file path.
function M.on_buf_enter()
	local curr_path = vim.api.nvim_buf_get_name(0)
	if curr_path == "" or curr_path:match("term://") then
		return
	end

	local nb = M.get_notebook_for_path(curr_path)
	if nb then
		M.switch_to_notebook(nb.id)
	elseif active then
		close_active()
	end
end

--- Registers a new directory as a notebook.
---
--- @param path string # Absolute path to the notebook
--- @param title string # User-friendly title
function M.register_notebook(path, title)
	if not registry then
		return
	end

	path = Paths.normalize(path)
	Paths.ensure_dir(path)

	if vim.fn.isdirectory(path) == 0 then
		Notify.error("path is not a valid directory: " .. path)
		return
	end

	local db_filename = title:gsub("%W", "_"):lower()
	local db_path = Cfg.notebook_dir .. "/" .. db_filename .. ".sqlite"

	local count = 0
	local base_path = db_path

	while vim.fn.filereadable(db_path) do
		count = count + 1
		db_path = base_path .. "(" .. count .. ").sqlite"
	end

	local success, _ = registry:insert("notebooks", {
		active = 1,
		db_path = db_path,
		path = path,
		title = title,
	})

	if not success then
		Notify.error("failed to register notebook")
		return
	end

	if active then
		close_active()
	end

	active = sqlite:open(db_path)
	if not active then
		Notify.error("unable to open new notebook")
	end

	active_title = title
end

--- Switches the active notebook to the specified notebook.
---
--- @param id integer # The notebook id
function M.switch_to_notebook(id)
	if not registry then
		return
	end

	if active then
		close_active()
	end

	--- @type BookwyrmBook
	local rows = registry:select("notebooks", {
		where = { id = id },
	})

	if not rows or #rows == 0 then
		Notify.error("notebook not found")
		return
	end

	local nb = rows[1]

	active = sqlite:open(nb.db_path)
	if not active then
		Notify.error("unable to open notebook db at: " .. nb.db_path)
	end

	active_title = nb.title
end

return M

--- @diagnostic disable: missing-fields

local M = {}

local Cfg = require("bookwyrm.config")
local Notify = require("bookwyrm.notify")
local Paths = require("bookwyrm.paths")

local has_sqlite, sqlite = pcall(require, "sqlite.db")
if not has_sqlite then
	require("bookwyrm.notify").error("sqlite required")
	return nil
end

---------------------------------------
--- State
---------------------------------------

--- @type sqlite_db
local registry = nil

--- @type sqlite_db?
local active = nil

--- @type integer?
local active_id = nil

--- @type string?
local active_title = nil

local save_cache = {}

-------------------------------------------------------------------------------
--- Init
-------------------------------------------------------------------------------

--- Initializes the registry db
---
--- @param path string # The path to the registry db
function M.init_registry(path)
	registry = sqlite:open(path)
	if not registry then
		Notify.error("registry is locked or inaccessible!")
	end

	registry:create("notebooks", {
		active = { type = "integer", required = true },
		db_path = { type = "text", unique = true, required = true },
		id = { type = "integer", primary = true, autoincrement = true },
		path = { type = "text", unique = true, required = true },
		title = { type = "text", required = true },

		--- @diagnostic disable-next-line: assign-type-mismatch
		ensure = true,
	})
end

--- Bootstraps the notebook db with the correct schemas.
---
--- @param db sqlite_db # The notebook db
local function bootstrap_notebook(db)
	db:eval("PRAGMA foreign_keys = ON;")

	local schemas = {
		[[
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL
      );
    ]],
		[[
      CREATE TABLE IF NOT EXISTS tags (
        note_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (note_id, tag),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
    ]],
		[[
      CREATE TABLE IF NOT EXISTS aliases (
        note_id INTEGER NOT NULL,
        alias TEXT NOT NULL,
        PRIMARY KEY (note_id, alias),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
    ]],
		[[
      CREATE TABLE IF NOT EXISTS anchors (
        note_id INTEGER NOT NULL,
        anchor_id TEXT NOT NULL,
        content TEXT NOT NULL,
        start_line INTEGER NOT NULL,
        start_char INTEGER NOT NULL,
        end_line INTEGER NOT NULL,
        end_char INTEGER NOT NULL,
        PRIMARY KEY (note_id, anchor_id),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
    ]],
		[[
      CREATE TABLE IF NOT EXISTS links (
        link_id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        target_note TEXT,
        target_anchor TEXT,
        context TEXT NOT NULL,
        start_line INTEGER NOT NULL,
        start_char INTEGER NOT NULL,
        end_line INTEGER NOT NULL,
        end_char INTEGER NOT NULL,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
    ]],
		[[
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        line INTEGER NOT NULL,
        status INTEGER DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
    ]],
	}

	for _, sql in ipairs(schemas) do
		local ok, err = pcall(function()
			db:eval(sql)
		end)

		if not ok then
			error("SQL Bootstrap Error: " .. tostring(err) .. "\nStatement: " .. sql)
		end
	end
end

-------------------------------------------------------------------------------
--- Registry
-------------------------------------------------------------------------------

---------------------------------------
--- Internal
---------------------------------------

local function close_active()
	if active then
		active:close()
		active = nil
		active_id = nil
		active_title = nil
		save_cache = {}
	end
end

local function is_markdown(bufnr)
	return vim.bo[bufnr].filetype == "markdown"
end

local function open_notebook(nb)
	close_active()

	active = sqlite:open(nb.db_path)
	if not active then
		Notify.error("unable to open notebook db at: " .. nb.db_path)
	end

	local status, err = pcall(function()
		bootstrap_notebook(active)
	end)

	if not status then
		close_active()

		Notify.error("bootstrap failed: " .. tostring(err))
		return
	end

	active_id = nb.id
	active_title = nb.title
end

---------------------------------------
--- Utility
---------------------------------------

--- Returns the active notebook title, if one is active. Can be used in
--- statuslines.
---
--- @return string?
function M.get_active_notebook()
	return active and active_title or nil
end

---------------------------------------
--- Operations
---------------------------------------

--- Deletes the notebook from the registry. This does not affect the filesystem.
---
--- @param id integer # The noteboook id
function M.delete_notebook(id)
	if not registry then
		return
	end

	if active and active_id == id then
		close_active()
	end

	local status, result = pcall(function()
		local rows = registry:select("notebooks", { where = { id = id } })
		assert(rows and #rows > 0, "could not find notebook")

		--- @diagnostic disable-next-line assign-type-mismatch
		assert(registry:delete("notebooks", { id = id }))

		return rows[1]
	end)

	if not status then
		Notify.error("could not delete: " .. tostring(result))
		return
	end

	local success, err = os.remove(result.db_path)
	if not success then
		Notify.warn("registry cleaned but could not delete file (" .. result.db_path .. ") for: " .. tostring(err))
	else
		Notify.info("successfully deleted notebook")
	end
end

--- Returns all registered notebooks.
---
--- @return BookwyrmBook[]
function M.get_notebooks()
	if not registry then
		return {}
	end

	--- @diagnostic disable-next-line missing-parameter
	return registry:select("notebooks")
end

--- Registers a new directory as a notebook.
---
--- @param path string # Absolute path to the notebook
--- @param title string # User-friendly title
--- @param silent boolean? # If it should be silent
function M.register_notebook(path, title, silent)
	if not registry then
		return
	end

	path = Paths.normalize(path)
	Paths.ensure_dir(path)

	if vim.fn.isdirectory(path) == 0 then
		Notify.error("path is not a valid directory: " .. path, silent)
		return
	end

	local db_filename = title:gsub("%W", "_"):lower()
	local db_path = Cfg.notebook_dir .. "/" .. db_filename .. ".sqlite"

	local count = 0
	local base_path = db_path

	while not vim.fn.filereadable(db_path) do
		count = count + 1
		if count >= 10 then
			break
		end

		db_path = base_path .. "(" .. count .. ").sqlite"
	end

	local success, id = registry:insert("notebooks", {
		active = 1,
		db_path = db_path,
		path = path,
		title = title,
	})

	if not success then
		Notify.error("failed to register notebook", silent)
		return
	end

	open_notebook({ db_path = db_path, id = id, title = title })
	Notify.info("Notebook registered: " .. title, silent)
end

--- Switches the active notebook to the specified notebook.
---
--- @param id integer # The notebook id
function M.switch_to_notebook(id)
	if not registry or active_id == id then
		return
	end

	--- @type BookwyrmBook
	local rows = registry:select("notebooks", {
		where = { id = id },
	})

	if not rows or #rows == 0 then
		Notify.error("notebook not found")
		return
	end

	open_notebook(rows[1])
end

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

--- Forces a save by clearing the cache for the given path.
---
--- @param path string? # The path to the file to save, or current buffer
function M.force_sync(path)
	path = path or vim.api.nvim_buf_get_name(0)
	save_cache[path] = nil
	M.save_note(path)
	Notify.info("forced sync for: " .. vim.fn.fnamemodify(path, ":t"))
end

--- Saves the note
---
---@param path string? # Path to buffer, or current buffer
function M.save_note(path)
	if not active then
		return
	end

	path = path or vim.api.nvim_buf_get_name(0)

	local bufnr = vim.fn.bufnr(path)
	if bufnr == -1 or not is_markdown(bufnr) then
		return
	end

	local tick = vim.api.nvim_buf_get_changedtick(bufnr)
	if save_cache[path] == tick then
		return
	end

	local note = require("bookwyrm.parser").parse_buffer(bufnr)

	local function batch_insert(table_name, items, mapper)
		if #items == 0 then
			return
		end

		local data = {}
		for _, item in ipairs(items) do
			table.insert(data, mapper(item))
		end

		if not active:insert(table_name, data) then
			error("batch insert failed for " .. table_name)
		end
	end

	local status, err = pcall(function()
		assert(active:eval("BEGIN TRANSACTION;"), "failed to begin transaction")

		local rows = active:eval(
			[[
      INSERT INTO notes (path, title) VALUES (:path, :title)
      ON CONFLICT(path) DO UPDATE SET title = excluded.title
      RETURNING id
    ]],
			{ path = note.path, title = note.title }
		)

		if not rows or #rows < 1 then
			error("note upsert failed")
		end

		local note_id = rows[1].id

		assert(active:delete("aliases", { note_id = note_id }), "failed to delete aliases")
		assert(active:delete("anchors", { note_id = note_id }), "failed to delete anchors")
		assert(active:delete("links", { note_id = note_id }), "failed to delete links")
		assert(active:delete("tags", { note_id = note_id }), "failed to delete tags")
		assert(active:delete("tasks", { note_id = note_id }), "failed to delete tasks")

		batch_insert("aliases", note.aliases, function(a)
			return { note_id = note_id, alias = a.alias }
		end)

		batch_insert("anchors", note.anchors, function(a)
			return {
				note_id = note_id,
				anchor_id = a.anchor_id,
				content = a.content,
				start_line = a.loc.start.line,
				start_char = a.loc.start.character,
				end_line = a.loc.finish.line,
				end_char = a.loc.finish.character,
			}
		end)

		batch_insert("links", note.links, function(l)
			return {
				note_id = note_id,
				target_note = l.target_note,
				target_anchor = l.target_anchor,
				context = l.context,
				start_line = l.loc.start.line,
				start_char = l.loc.start.character,
				end_line = l.loc.finish.line,
				end_char = l.loc.finish.character,
			}
		end)

		batch_insert("tags", note.tags, function(t)
			return { note_id = note_id, tag = t.tag }
		end)

		batch_insert("tasks", note.tasks, function(t)
			return {
				note_id = note_id,
				line = t.line,
				content = t.content,
				status = t.status,
			}
		end)

		assert(active:eval("COMMIT;"), "failed to commit")
		save_cache[path] = tick
	end)

	if not status then
		if active then
			active:eval("ROLLBACK;")
		end

		Notify.error("critical save error: " .. tostring(err))
	end
end

return M

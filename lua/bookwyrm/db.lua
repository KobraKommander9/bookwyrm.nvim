--- @diagnostic disable: missing-fields

local M = {}

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

--- @type sqlite_db?
local registry = nil

--- @type sqlite_db?
local active = nil

--- @type BookwyrmBook?
local active_nb = nil

local save_cache = {}

---------------------------------------
--- Utility
---------------------------------------

--- @param db sqlite_db
--- @param table_name string
--- @param items table[]
--- @param mapper function
local function batch_insert(db, table_name, items, mapper)
	if #items == 0 then
		return
	end

	local data = {}
	for _, item in ipairs(items) do
		table.insert(data, mapper(item))
	end

	if not db:insert(table_name, data) then
		error("batch insert failed for " .. table_name)
	end
end

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
		return
	end

	registry:create("notebooks", {
		active = { type = "integer", required = true },
		db_path = { type = "text", unique = true, required = true },
		id = { type = "integer", primary = true, autoincrement = true },
		is_default = { type = "integer", default = "0" },
		path = { type = "text", unique = true, required = true },
		title = { type = "text", required = true },

		--- @diagnostic disable-next-line: assign-type-mismatch
		ensure = true,
	})
end

function M.migrate_registry(path)
	if not registry then
		return
	end

	local old_notebooks = M.get_notebooks()

	registry:close()
	registry = nil

	local success, err = os.remove(path)
	if not success and vim.fn.filereadable(path) == 1 then
		Notify.error("registry migration failed: " .. tostring(err))
		return
	end

	M.init_registry(path)

	success, err = pcall(batch_insert, registry, "notebooks", old_notebooks, function(nb)
		return {
			active = nb.active,
			db_path = nb.db_path,
			is_default = nb.is_default or 0,
			path = nb.path,
			title = nb.title,
		}
	end)
	if not success then
		Notify.error("failed to reregister old notebooks: " .. tostring(err))
	end
end

-------------------------------------------------------------------------------
--- Registry
-------------------------------------------------------------------------------

---------------------------------------
--- Internal
---------------------------------------

local function is_markdown(bufnr)
	return vim.bo[bufnr].filetype == "markdown"
end

---------------------------------------
--- Utility
---------------------------------------

--- Returns the active notebook title, if one is active. Can be used in
--- statuslines.
---
--- @return BookwyrmBook?
function M.get_active_notebook()
	return active and active_nb or nil
end

--- Loads the default active notebook.
function M.load_active_notebook()
	if not registry then
		return
	end

	local rows = registry:select("notebooks", { where = { is_default = 1 } })
	if rows and #rows > 0 then
		M.switch_to_notebook(rows[1].id)
	end
end

---------------------------------------
--- Operations
---------------------------------------

--- Returns the notebook that owns the given path, if any.
---
--- @param path string # The path to check
--- @return BookwyrmBook?
function M.get_notebook_for_path(path)
	if not registry then
		return nil
	end

	local rows = registry:select("notebooks", { where = { active = 1 } })
	if not rows or #rows == 0 then
		return nil
	end

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

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

---------------------------------------
--- Utility
---------------------------------------

--- Checks if the saved file belongs in a notebook and will write it to the
--- appropriate notebook.
function M.on_save()
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" or not is_markdown(0) then
		return
	end

	local nb = M.get_notebook_for_path(path)
	if not nb then
		return
	end

	if not active_nb or active_nb.id ~= nb.id then
		M.switch_to_notebook(nb.id)
	end

	M.save_note(path)
end

--- Resyncs the active notebook with the filesystem.
function M.resync()
	if not active then
		return
	end

	--- @diagnostic disable-next-line missing-parameter
	local rows = active:select("notes")
	local deleted_count = 0

	for _, note in ipairs(rows or {}) do
		if vim.fn.filereadable(note.path) == 0 then
			active:delete("notes", { id = note.id })
			deleted_count = deleted_count + 1
		end
	end

	M.scan_notebook()

	if deleted_count > 0 then
		Notify.info(string.format("Resync: Cleaned %d orphaned records.", deleted_count))
	end
end

---------------------------------------
--- Operations
---------------------------------------

--- Creates a new note file in the active notebook. Returns the created note if
--- successful.
---
--- @param title string # the title of the new note
--- @return BookwyrmNote?
function M.create_note(title)
	if not active or not active_nb then
		Notify.error("No active notebook to create note in.")
		return nil
	end

	if not title or title == "" then
		Notify.error("Note title required")
		return nil
	end

	local slug = title:gsub("%s+", "-"):gsub("[^%w%-]", ""):lower()
	local filename = slug .. ".md"
	local full_path = Paths.normalize(active_nb.path .. "/" .. filename)

	local rows = active:select("notes", { where = { path = full_path } })
	if rows and #rows > 0 then
		return rows[1]
	end

	local f = io.open(full_path, "w")
	if f then
		f:write("---\n")
		f:write("title: " .. title .. "\n")
		f:write("---\n\n")
		f:close()
	end

	local nb = {
		path = full_path,
		title = title,
	}

	local success, id = active:insert("notes", nb)
	if not success then
		Notify.warn("Failed to sync new note")
	end

	nb.id = id

	return nb
end

--- Forces a save by clearing the cache for the given path.
---
--- @param path string? # The path to the file to save, or current buffer
function M.force_sync(path)
	path = path or vim.api.nvim_buf_get_name(0)
	save_cache[path] = nil
	M.save_note(path)
	Notify.info("forced sync for: " .. vim.fn.fnamemodify(path, ":t"))
end

--- Returns all notes for the active notebook.
---
--- @return BookwyrmNote[]
function M.get_notes()
	if not active then
		return {}
	end

	--- @diagnostic disable-next-line missing-parameter
	return active:select("notes")
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

		batch_insert(active, "aliases", note.aliases, function(a)
			return { note_id = note_id, alias = a.alias }
		end)

		batch_insert(active, "anchors", note.anchors, function(a)
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

		batch_insert(active, "links", note.links, function(l)
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

		batch_insert(active, "tags", note.tags, function(t)
			return { note_id = note_id, tag = t.tag }
		end)

		batch_insert(active, "tasks", note.tasks, function(t)
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

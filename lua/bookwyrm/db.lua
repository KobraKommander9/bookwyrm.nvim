--- @diagnostic disable: missing-fields

local M = {}

local Notify = require("bookwyrm.notify")
local Paths = require("bookwyrm.paths")

---------------------------------------
--- State
---------------------------------------

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

---------------------------------------
--- Internal
---------------------------------------

local function is_markdown(bufnr)
	return vim.bo[bufnr].filetype == "markdown"
end

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

---------------------------------------
--- Utility
---------------------------------------

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

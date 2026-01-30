--- @diagnostic disable: missing-fields

--- @class BookwyrmNotebookDB
--- @field book BookwyrmBook
--- @field db sqlite_db
--- @field silent boolean?
local Notebook = {}

local notify = require("bookwyrm.util.notify")
local Q = require("bookwyrm.core.db.queries")

Notebook.__index = Notebook

function Notebook:__tostring()
	return string.format("NotebookDB(%s): %s", self.book.title, self.book.db_path)
end

local MIGRATIONS = {
	{
		id = "001_init_db",
		script = [[
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL
      );
      
      CREATE TABLE IF NOT EXISTS tags (
        note_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (note_id, tag),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
      
      CREATE TABLE IF NOT EXISTS aliases (
        note_id INTEGER NOT NULL,
        alias TEXT NOT NULL,
        PRIMARY KEY (note_id, alias),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
      
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

      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        line INTEGER NOT NULL,
        status INTEGER DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
    ]],
	},
}

--- Opens a connection to the notebook db.
---
--- @param nb BookwyrmBook
--- @param silent boolean? # If notifications should be silenced
--- @return BookwyrmNotebookDB?
function Notebook.open(nb, silent)
	local db = require("sqlite.db"):open(nb.db_path)
	if not db then
		notify.error("unable to access notebook db", silent)
		return nil
	end

	local success = db:eval("PRAGMA foreign_keys = ON;")
	if not success then
		notify.error("unable to connect to db", silent)
		return nil
	end

	local instance = setmetatable({
		book = nb,
		db = db,
		silent = silent,
	}, Notebook)

	local status, err = pcall(function()
		instance:migrate()
	end)

	if not status then
		notify.error("failed to migrate notebook: " .. tostring(err), silent)
		return nil
	end

	return instance
end

--- Closes the notebook.
function Notebook:close()
	self.db:close()
end

--- Migrates the bookwyrm notebook db.
function Notebook:migrate()
	assert(self.db:eval([[ CREATE TABLE IF NOT EXISTS _migrations (id TEXT PRIMARY KEY); ]]))

	--- @diagnostic disable-next-line missing-parameter
	local ran = self.db:select("_migrations")

	local ran_map = {}
	for _, row in ipairs(ran) do
		ran_map[row.id] = true
	end

	for _, migration in ipairs(MIGRATIONS) do
		local id, script = migration.id, migration.script

		if not ran_map[id] then
			assert(self.db:eval(script), "Migration [" .. id .. "] failed")
			assert(self.db:insert("_migrations", { id = id }))
		end
	end
end

-------------------------------------------------------------------------------
--- Operations
-------------------------------------------------------------------------------

--- Gets the note for the provided path, if any.
---
--- @param path string # The full path to the note.
--- @return BookwyrmNote?
function Notebook:get_for_path(path)
	local status, result = pcall(function()
		local rows = self.db:select("notes", { where = { path = path } })
		assert(rows and #rows > 0)
		return rows[1]
	end)

	if not status then
		return nil
	end

	return result
end

--- Lists all notes.
---
--- @return BookwyrmNote[]
function Notebook:list()
	local status, result = pcall(function()
		--- @diagnostic disable-next-line missing-parameter
		local rows = self.db:select("notes")
		assert(rows, "could not list notes")

		return rows
	end)

	if not status then
		notify.error(tostring(result), self.silent)
		return {}
	end

	return result
end

--- Saves a note.
---
--- @param nb BookwyrmNote # The note to save
--- @return BookwyrmNote?
function Notebook:save(nb)
	local status, result = pcall(function()
		assert(self.db:eval("BEGIN TRANSACTION;"), "failed to begin transaction")

		local rows = self.db:eval(
			[[
      INSERT INTO notes (path, title) VALUES (:path, :title)
      ON CONFLICT(path) DO UPDATE SET title = excluded.title
      RETURNING id
    ]],
			{ path = nb.path, title = nb.title }
		)

		if not rows or #rows < 1 then
			error("note upsert failed")
		end

		local note_id = rows[1].id

		assert(self.db:delete("aliases", { note_id = note_id }), "failed to delete aliases")
		assert(self.db:delete("anchors", { note_id = note_id }), "failed to delete anchors")
		assert(self.db:delete("links", { note_id = note_id }), "failed to delete links")
		assert(self.db:delete("tags", { note_id = note_id }), "failed to delete tags")
		assert(self.db:delete("tasks", { note_id = note_id }), "failed to delete tasks")

		Q.batch_insert(self.db, "aliases", nb.aliases, function(a)
			return { note_id = note_id, alias = a.alias }
		end)

		Q.batch_insert(self.db, "anchors", nb.anchors, function(a)
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

		Q.batch_insert(self.db, "links", nb.links, function(l)
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

		Q.batch_insert(self.db, "tags", nb.tags, function(t)
			return { note_id = note_id, tag = t.tag }
		end)

		Q.batch_insert(self.db, "tasks", nb.tasks, function(t)
			return {
				note_id = note_id,
				line = t.line,
				content = t.content,
				status = t.status,
			}
		end)

		assert(self.db:eval("COMMIT;"), "failed to commit")

		return note_id
	end)

	if not status then
		notify.error("failed to save note: " .. tostring(result), self.silent)
		return nil
	end

	nb.id = result

	return nb
end

return Notebook

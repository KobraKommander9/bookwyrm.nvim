--- @class BookwyrmNotebookDB
--- @field book BookwyrmBook
--- @field db sqlite_db
--- @field silent boolean?
local Notebook = {}

local notify = require("bookwyrm.util.notify")

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

return Notebook

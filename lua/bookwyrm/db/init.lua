--- @diagnostic disable: missing-fields

--- @class BookwyrmDB
--- @field db sqlite_db
--- @field silent boolean?
local DB = {}

local notify = require("bookwyrm.util.notify")

DB.__index = DB

function DB:__tostring()
	return "DB"
end

local MIGRATIONS = {
	{
		id = "001_init_db",
		script = [[
      CREATE TABLE notebooks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        is_default INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        root_path TEXT NOT NULL,
        title TEXT NOT NULL
        UNIQUE(is_default),
        UNIQUE(root_path)
      );

      CREATE TABLE notes (
        fsize INTEGER,
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mtime INTEGER,
        notebook_id INTEGER NOT NULL, 
        relative_path TEXT NOT NULL,
        title TEXT,
        UNIQUE(notebook_id, relative_path),
        FOREIGN KEY (notebook_id) REFERENCES notebooks(id) ON DELETE CASCADE
      );

      CREATE TABLE anchors (
        anchor_id TEXT NOT NULL,
        content TEXT NOT NULL,
        note_id INTEGER NOT NULL, 
        type TEXT NOT NULL,
        
        start_line INTEGER NOT NULL,
        start_char INTEGER NOT NULL,
        end_line INTEGER NOT NULL,
        end_char INTEGER NOT NULL,

        PRIMARY KEY (note_id, anchor_id),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );

      CREATE TABLE links (
        context TEXT NOT NULL,
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        target_note TEXT,
        target_note_id INTEGER,
        target_anchor TEXT,
        
        start_line INTEGER NOT NULL,
        start_char INTEGER NOT NULL,
        end_line INTEGER NOT NULL,
        end_char INTEGER NOT NULL,

        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY (target_note_id) REFERENCES notes(id) ON DELETE SET NULL
      );

      CREATE TABLE aliases (
        alias TEXT NOT NULL,
        note_id INTEGER NOT NULL,
        PRIMARY KEY (note_id, alias),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );

      CREATE TABLE tags (
        note_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (note_id, tag),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );

      CREATE TABLE tasks (
        content TEXT NOT NULL,
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        line INTEGER NOT NULL,
        note_id INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
      );
    ]],
	},
}

--- Opens a connection to the notebook db.
---
--- @param path string # The path to the db
--- @param silent boolean? # If notifications should be silenced
--- @return BookwyrmDB?
function DB.open(path, silent)
	local has_sqlite, sqlite = pcall(require, "sqlite.db")
	if not has_sqlite then
		return nil
	end

	local db = sqlite:open(path)
	if not db then
		notify.error("unable to access db", silent)
		return nil
	end

	local success = db:eval("PRAGMA foreign_keys = ON;")
	if not success then
		notify.error("unable to connect to db", silent)
		return nil
	end

	local instance = setmetatable({
		db = db,
		silent = silent,
	}, DB)

	local status, err = pcall(function()
		instance:migrate()
	end)

	if not status then
		notify.error("failed to migrate notebook: " .. tostring(err), silent)
		return nil
	end

	return instance
end

--- Migrates the bookwyrm db.
function DB:migrate()
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
--- Notebooks
-------------------------------------------------------------------------------

--- Deletes the notebook from the db.
---
--- @param id integer # The notebook id
--- @return BookwyrmBook? # The deleted notebook if successful
function DB:delete_notebook(id)
	local status, result = pcall(function()
		local rows = self.db:select("notebooks", { where = { id = id } })
		assert(rows and #rows > 0, "could not find notebook")

		--- @diagnostic disable-next-line assign-type-mismatch
		assert(self.db:delete("notebooks", { id = id }))

		return rows[1]
	end)

	if not status then
		notify.error(tostring(result), self.silent)
		return nil
	end

	return result
end

--- Gets the specified notebook.
---
--- @param id integer # The notebook id
--- @return BookwyrmBook?
function DB:get_notebook(id)
	local status, result = pcall(function()
		local rows = self.db:select("notebooks", { where = { id = id } })
		assert(rows and #rows == 1)
		return rows[1]
	end)

	if not status then
		return nil
	end

	return result
end

--- Gets the default notebook, if any.
---
--- @return BookwyrmBook?
function DB:get_default_notebook()
	local status, result = pcall(function()
		local rows = self.db:select("notebooks", { where = { is_default = 1 } })
		assert(rows and #rows == 1)
		return rows[1]
	end)

	if not status then
		return nil
	end

	return result
end

--- Lists all registered notebooks.
---
--- @return BookwyrmBook[]
function DB:list_notebooks()
	local status, result = pcall(function()
		--- @diagnostic disable-next-line missing-parameter
		local rows = self.db:select("notebooks")
		assert(rows, "could not list notebooks")

		return rows
	end)

	if not status then
		notify.error(tostring(result), self.silent)
		return {}
	end

	return result
end

--- Registers a new notebook.
---
--- @param nb BookwyrmBook # The notebook to register
--- @return integer? # The id of the created notebook, if successful
function DB:register_notebook(nb)
	local success, id = self.db:insert("notebooks", {
		priority = nb.priority,
		root_path = nb.root_path,
		title = nb.title,
	})
	if not success then
		return nil
	end

	return id
end

--- Renames the notebook.
---
--- @param title string # The new title
--- @param id integer # The id of the notebook to rename.
--- @return boolean # If the operation was a success.
function DB:rename_notebook(title, id)
	return self.db:update("notebooks", {
		where = { id = id },
		set = { title = title },
	})
end

--- Sets the default notebook.
---
--- @param id integer # The id of the notebook to set as default
--- @return boolean # If the operation was a success.
function DB:set_default_notebook(id)
	local status, err = pcall(function()
		assert(self.db:eval("BEGIN TRANSACTION;"), "failed to begin transaction")
		assert(self.db:eval("UPDATE notebooks SET is_default = 0 WHERE is_default = 1;"))
		assert(self.db:eval("UPDATE notebooks SET is_default = 1 WHERE id = :id;", { id = id }))
		assert(self.db:eval("COMMIT;"), "failed to commit transaction")
	end)

	if not status then
		self.db:eval("ROLLBACK;")
		notify.error("could not set default notebook: " .. tostring(err))
		return false
	end

	return true
end

return DB

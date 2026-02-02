--- @diagnostic disable: missing-fields

--- @class BookwyrmDB
--- @field conn sqlite_db
--- @field notebooks BookwyrmNotebookDB
--- @field notes BookwyrmNoteDB
local DB = {}

local notify = require("bookwyrm.util.notify")

DB.__index = DB
DB.__tostring = function()
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
        title TEXT NOT NULL,
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
		conn = db,
	}, DB)

	local status, err = pcall(function()
		instance:migrate()
	end)

	if not status then
		notify.error("failed to migrate notebook: " .. tostring(err), silent)
		return nil
	end

	instance.notebooks = require("bookwyrm.db.notebook").new(db, silent)
	instance.notes = require("bookwyrm.db.note").new(db, silent)

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("BookwyrmDB", { clear = true }),
		callback = function()
			instance:close()
		end,
	})

	return instance
end

--- Closes the db.
function DB:close()
	if not self.conn:isclose() then
		self.conn:close()
	end
end

--- Migrates the bookwyrm db.
function DB:migrate()
	assert(self.conn:eval([[ CREATE TABLE IF NOT EXISTS _migrations (id TEXT PRIMARY KEY); ]]))

	--- @diagnostic disable-next-line missing-parameter
	local ran = self.conn:select("_migrations")

	local ran_map = {}
	for _, row in ipairs(ran) do
		ran_map[row.id] = true
	end

	for _, migration in ipairs(MIGRATIONS) do
		local id, script = migration.id, migration.script

		if not ran_map[id] then
			assert(self.conn:eval(script), "Migration [" .. id .. "] failed")
			assert(self.conn:insert("_migrations", { id = id }))
		end
	end
end

return DB

--- @class db.BookwyrmBook
--- @field db sqlite_db?
--- @field nb BookwyrmBook?
local Notebook = {}

local has_sqlite, sqlite = pcall(require, "sqlite.db")
if not has_sqlite then
	error("sqlite required")
end

Notebook.__index = Notebook

function Notebook:__tostring()
	if not self.nb then
		return "Notebook(nil)"
	end

	return string.format("Notebook(%s): %s", self.nb.title, self.nb.db_path)
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

--- Closes the notebook.
function Notebook:close()
	if not self.db then
		return
	end

	self.db:close()
	self.db = nil
	self.nb = nil
end

--- Opens the notebook.
---
--- @param nb BookwyrmBook # The notebook to open
--- @return db.BookwyrmBook?
function Notebook.open(nb)
	local db = sqlite:open(nb.db_path)
	if not db then
		error("unable to open notebook at: " .. nb.db_path)
	end

	bootstrap_notebook(db)

	return setmetatable({
		db = db,
		nb = nb,
	}, Notebook)
end

return Notebook

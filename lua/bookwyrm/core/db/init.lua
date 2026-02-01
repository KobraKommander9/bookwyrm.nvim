--- @diagnostic disable: missing-fields

local DB = {}

local notify = require("bookwyrm.util.notify")

DB.__index = DB

local MIGRATIONS = {
	{
		id = "001_init_db",
		script = [[
      CREATE TABLE IF NOT EXISTS notebooks (
        db_path TEXT NOT NULL UNIQUE,
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        is_default INTEGER NOT NULL DEFAULT 0,
        path TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL
      );
    ]],
	},
}

--- Opens a connection to the bookwyrm db.
---
--- @param path string # The registry db path
--- @param silent boolean? # If the notifications should be silenced
--- @return BookwyrmDB?
function DB.open(path, silent)
	local has_sqlite, sqlite = pcall(require, "sqlite.db")
	if not has_sqlite then
		return nil
	end

	local db = sqlite:open(path)
	if not db then
		notify.error("db is locked or inaccessible", silent)
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
		notify.error("failed to migrate registry: " .. tostring(err), silent)
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
--- Operations
-------------------------------------------------------------------------------

--- Deletes the notebook from the db.
---
--- @param id integer # The notebook id
--- @return BookwyrmBook? # The deleted notebook if successful
function DB:delete(id)
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
function DB:get(id)
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
function DB:get_default()
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
function DB:list()
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
function DB:register(nb)
	local success, id = self.db:insert("notebooks", {
		db_path = nb.db_path,
		path = nb.path,
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
function DB:rename(title, id)
	return self.db:update("notebooks", {
		where = { id = id },
		set = { title = title },
	})
end

--- Sets the default notebook.
---
--- @param id integer # The id of the notebook to set as default
--- @return boolean # If the operation was a success.
function DB:set_default(id)
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

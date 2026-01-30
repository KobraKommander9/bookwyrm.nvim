--- @class BookwyrmDB
--- @field db sqlite_db
local DB = {}

local notify = require("bookwyrm.util.notify")
local state = require("bookwyrm.core.state")

DB.__index = DB

function DB:__tostring()
	return "DB"
end

local MIGRATIONS = {
	{
		id = "001_init_registry",
		sql = [[
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
--- @return BookwyrmDB?
function DB.open()
	local has_sqlite, sqlite = pcall(require, "sqlite.db")
	if not has_sqlite then
		return nil
	end

	local db = sqlite:open(state.cfg.registry_path)
	if not db then
		notify.error("db is locked or inaccessible", state.cfg.silent)
		return nil
	end

	local instance = setmetatable({
		db = db,
	}, DB)

	local status, err = pcall(function()
		instance:migrate()
	end)

	if not status then
		notify.error("failed to migrate: " .. tostring(err))
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

return DB

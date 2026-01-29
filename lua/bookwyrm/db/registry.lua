--- @diagnostic disable: missing-fields

--- @class db.BookwyrmRegistry
--- @field db sqlite_db
--- @field nb db.BookwyrmBook?
local Registry = {}

local Cfg = require("bookwyrm.config")
local Q = require("bookwyrm.db.queries")

local has_sqlite, sqlite = pcall(require, "sqlite.db")
if not has_sqlite then
	error("sqlite required")
end

Registry.__index = Registry

function Registry:__tostring()
	if not self.nb then
		return "Registry"
	end

	return string.format("Registry, Active: %s", tostring(self.nb))
end

--- Returns all registered notebooks.
---
--- @return BookwyrmBook[]
function Registry:get_notebooks()
	--- @diagnostic disable-next-line missing-parameter
	return self.db:select("notebooks")
end

--- Migrates the connection.
---
--- @param reg db.BookwyrmRegistry # The registry to migrate
local function migrate(reg)
	local old_notebooks = reg:get_notebooks()

	reg.db:close()

	local success, err = os.remove(Cfg.registry_path)
	if not success and vim.fn.filereadable(Cfg.registry_path) == 1 then
		error("registry migration failed: " .. tostring(err))
	end

	reg.db = sqlite:open(Cfg.registry_path)
	if not reg.db then
		error("registry is locked or inaccessible")
	end

	reg.db:create("notebooks", {
		active = { type = "integer", required = true },
		db_path = { type = "text", unique = true, required = true },
		id = { type = "integer", primary = true, autoincrement = true },
		is_default = { type = "integer", default = "0" },
		path = { type = "text", unique = true, required = true },
		title = { type = "text", required = true },

		--- @diagnostic disable-next-line: assign-type-mismatch
		ensure = true,
	})

	Q.batch_insert(reg.db, "notebooks", old_notebooks, function(nb)
		return {
			active = nb.active,
			db_path = nb.db_path,
			is_default = nb.is_default or 0,
			path = nb.path,
			title = nb.title,
		}
	end)
end

--- Opens a connection to the notebook registry.
function Registry.open()
	local registry = sqlite:open(Cfg.registry_path)
	if not registry then
		error("registry is locked or inaccessible")
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

	local reg = setmetatable({
		db = registry,
		nb = nil,
	}, Registry)

	if Cfg.recreate_registry then
		migrate(reg)
	end

	return reg
end

return Registry

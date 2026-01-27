local M = {}

local has_sqlite, sqlite = pcall(require, "sqlite")
if not has_sqlite then
	require("bookwyrm.message").error("SQLite not found")
	return
end

local cfg = require("bookwyrm.config")
local db = sqlite.new(cfg.options.db)

db:with_open(function()
	db:create("notes", {
		id = { "integer", primary = true, autoincrement = true },
		path = { "text", unique = true, required = true },
		title = "text",
		type = "text",
		update_time = { "text", default = "CURRENT_TIMESTAMP" },
	})

	db:create("aliases", {
		alias = { "text", required = true },
		id = { "integer", primary = true, autoincrement = true },
		note_id = { "integer", required = true, foreign_key = { "notes", "id", on_delete = "cascade" } },
	})

	db:create("tasks", {
		content = "text",
		completed = { "integer", default = 0 },
		id = { "integer", primary = true, autoincrement = true },
		line = "integer",
		note_id = { "integer", required = true, foreign_key = { "notes", "id", on_delete = "cascade" } },
	})

	db:create("links", {
		col = { "integer", required = true },
		content = "text",
		id = { "integer", primary = true, autoincrement = true },
		line = { "integer", required = true },
		note_id = { "integer", required = true, foreign_key = { "notes", "id", on_delete = "cascade" } },
		target = { "text", required = true },
	})
end)

---@param path string # Path to buffer
function M.save_note(path)
	local bufnr = vim.fn.bufnr(path)
	local parsed_data = require("bookwyrm.parser").parse_buffer(bufnr)
end

return M

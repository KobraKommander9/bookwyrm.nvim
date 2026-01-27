local M = {}

local has_sqlite, sqlite = pcall(require, "sqlite")

local cfg = require("bookwyrm.config")
local db

function M.init()
	if not has_sqlite then
		require("bookwyrm.message").error("sqlite required")
		return
	end

	db = sqlite.new(cfg.options.db)

	db:with_open(function()
		db:eval("PRAGMA foreign_keys = ON;")

		db:create("notes", {
			id = { "integer", primary = true, autoincrement = true },
			path = { "text", unique = true, required = true },
			title = { "text", required = true },
			update_time = { "text", default = "CURRENT_TIMESTAMP" },
		})

		db:create("tags", {
			note_id = { "integer", foreign_key = { "notes", "id", on_delete = "cascade" } },
			tag = { "text", required = true },

			primary = { "note_id", "tag" },
		})

		db:create("aliases", {
			alias = { "text", required = true },
			note_id = { "integer", foreign_key = { "notes", "id", on_delete = "cascade" } },

			primary = { "note_id", "alias" },
		})

		db:create("anchors", {
			anchor_id = { "text", required = true },
			content = { "text", required = true },
			note_id = { "integer", foreign_key = { "notes", "id", on_delete = "cascade" } },

			start_line = { "integer", required = true },
			start_char = { "integer", required = true },
			end_line = { "integer", required = true },
			end_char = { "integer", required = true },

			primary = { "note_id", "anchor_id" },
		})

		db:create("links", {
			col = { "integer", required = true },
			content = { "text", required = true },
			line = { "integer", required = true },
			note_id = { "integer", foreign_key = { "notes", "id", on_delete = "cascade" } },
			target_anchor = "text",
			target_note = { "text", required = true },
		})

		db:create("tasks", {
			content = { "text", required = true },
			completed = { "integer", default = 0 },
			id = { "integer", primary = true, autoincrement = true },
			line = { "integer", required = true },
			note_id = { "integer", required = true, foreign_key = { "notes", "id", on_delete = "cascade" } },
		})
	end)
end

---@param path string # Path to buffer
function M.save_note(path)
	local bufnr = vim.fn.bufnr(path)
	local parsed_data = require("bookwyrm.parser").parse_buffer(bufnr)
end

return M

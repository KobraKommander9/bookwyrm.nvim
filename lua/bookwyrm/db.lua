local M = {}

local has_sqlite, sqlite = pcall(require, "sqlite")

local cfg = require("bookwyrm.config")
local db

function M.init()
	if not has_sqlite then
		require("bookwyrm.notify").error("sqlite required")
		return
	end

	db = sqlite.new(cfg.options.db)

	db:with_open(function()
		db:eval("PRAGMA foreign_keys = ON;")

		db:create("notes", {
			id = { "integer", primary = true, autoincrement = true },
			path = { "text", unique = true, required = true },
			title = { "text", required = true },
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
			context = { "text", required = true },
			note_id = { "integer", foreign_key = { "notes", "id", on_delete = "cascade" } },
			target_anchor = "text",
			target_note = "text",

			start_line = { "integer", required = true },
			start_char = { "integer", required = true },
			end_line = { "integer", required = true },
			end_char = { "integer", required = true },
		})

		db:create("tasks", {
			content = { "text", required = true },
			id = { "integer", primary = true, autoincrement = true },
			line = { "integer", required = true },
			note_id = { "integer", required = true, foreign_key = { "notes", "id", on_delete = "cascade" } },
			status = { "integer", default = 0 },
		})
	end)
end

--- Saves the note
---
---@param path string # Path to buffer
function M.save_note(path)
	local bufnr = vim.fn.bufnr(path)
	local note = require("bookwyrm.parser").parse_buffer(bufnr)

	db:with_transaction(function()
		local note_id = db:eval(
			[[
      INSERT INTO notes (path, title) VALUES (:path, :title)
      ON CONFLICT(path) DO UPDATE SET title = excluded.title
      RETURNING id
    ]],
			{ path = note.path, title = note.title }
		)[1].id

		db:execute("DELETE FROM aliases WHERE note_id = ?", note_id)
		db:execute("DELETE FROM anchors WHERE note_id = ?", note_id)
		db:execute("DELETE FROM links WHERE note_id = ?", note_id)
		db:execute("DELETE FROM tags WHERE note_id = ?", note_id)
		db:execute("DELETE FROM tasks WHERE note_id = ?", note_id)

		for _, alias in ipairs(note.aliases) do
			db:execute(
				[[
        INSERT INTO aliases (note_id, alias)
        VALUES (?, ?)
      ]],
				note_id,
				alias.alias
			)
		end

		for _, anchor in ipairs(note.anchors) do
			db:execute(
				[[
        INSERT INTO anchors (note_id, anchor_id, content, start_line, start_char, end_line, end_char)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ]],
				note_id,
				anchor.anchor_id,
				anchor.content,
				anchor.loc.start.line,
				anchor.loc.start.character,
				anchor.loc.finish.line,
				anchor.loc.finish.character
			)
		end

		for _, link in ipairs(note.links) do
			db:execute(
				[[
        INSERT INTO links (note_id, target_note, target_anchor, context, start_line, start_char, end_line, end_char)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ]],
				note_id,
				link.target_note,
				link.target_anchor,
				link.context,
				link.loc.start.line,
				link.loc.start.character,
				link.loc.finish.line,
				link.loc.finish.character
			)
		end

		for _, tag in ipairs(note.tags) do
			db:execute("INSERT INTO tags (note_id, tag) VALUES (?, ?)", note_id, tag.tag)
		end

		for _, task in ipairs(note.tasks) do
			db:execute(
				[[
        INSERT INTO tasks (note_id, line, content, status)
        VALUES (?, ?, ?, ?)
      ]],
				note_id,
				task.line,
				task.content,
				task.status
			)
		end
	end)
end

return M

--- @diagnostic disable: missing-fields

--- @class BookwyrmNoteDB
--- @field conn sqlite_db
--- @field silent boolean?
local Note = {}

local notify = require("bookwyrm.util.notify")
local Q = require("bookwyrm.db.queries")

Note.__index = Note
Note.__tostring = function()
	return "Note"
end

--- Creates the notebook db helper.
---
--- @param conn sqlite_db # The sqlite connection
--- @param silent boolean? # If the operations should be silent
--- @return BookwyrmNoteDB
function Note.new(conn, silent)
	return setmetatable({
		conn = conn,
		silent = silent,
	}, Note)
end

--- --- Gets the note for the provided path, if any.
--- ---
--- --- @param path string # The full path to the note.
--- --- @return BookwyrmNote?
--- function Note:get_for_path(path)
--- 	local status, result = pcall(function()
--- 		local rows = self.conn:select("notes", { where = { path = path } })
--- 		assert(rows and #rows > 0)
--- 		return rows[1]
--- 	end)
---
--- 	if not status then
--- 		return nil
--- 	end
---
--- 	return result
--- end
---
--- --- Lists all notes.
--- ---
--- --- @return BookwyrmNote[]
--- function Note:list()
--- 	local status, result = pcall(function()
--- 		--- @diagnostic disable-next-line missing-parameter
--- 		local rows = self.db:select("notes")
--- 		assert(rows, "could not list notes")
---
--- 		return rows
--- 	end)
---
--- 	if not status then
--- 		notify.error(tostring(result), self.silent)
--- 		return {}
--- 	end
---
--- 	return result
--- end
---
--- --- Saves a note.
--- ---
--- --- @param nb BookwyrmNote # The note to save
--- --- @return BookwyrmNote?
--- function Note:save(nb)
--- 	local status, result = pcall(function()
--- 		assert(self.conn:eval("BEGIN TRANSACTION;"), "failed to begin transaction")
---
--- 		local rows = self.conn:eval(
--- 			[[
---       INSERT INTO notes (path, title) VALUES (:path, :title)
---       ON CONFLICT(path) DO UPDATE SET title = excluded.title
---       RETURNING id
---     ]],
--- 			{ path = nb.path, title = nb.title }
--- 		)
---
--- 		if not rows or #rows < 1 then
--- 			error("note upsert failed")
--- 		end
---
--- 		local note_id = rows[1].id
---
--- 		assert(self.conn:delete("aliases", { note_id = note_id }), "failed to delete aliases")
--- 		assert(self.conn:delete("anchors", { note_id = note_id }), "failed to delete anchors")
--- 		assert(self.conn:delete("links", { note_id = note_id }), "failed to delete links")
--- 		assert(self.conn:delete("tags", { note_id = note_id }), "failed to delete tags")
--- 		assert(self.conn:delete("tasks", { note_id = note_id }), "failed to delete tasks")
---
--- 		Q.batch_insert(self.conn, "aliases", nb.aliases, function(a)
--- 			return { note_id = note_id, alias = a.alias }
--- 		end)
---
--- 		Q.batch_insert(self.conn, "anchors", nb.anchors, function(a)
--- 			return {
--- 				note_id = note_id,
--- 				anchor_id = a.anchor_id,
--- 				content = a.content,
--- 				start_line = a.loc.start.line,
--- 				start_char = a.loc.start.character,
--- 				end_line = a.loc.finish.line,
--- 				end_char = a.loc.finish.character,
--- 			}
--- 		end)
---
--- 		Q.batch_insert(self.conn, "links", nb.links, function(l)
--- 			return {
--- 				note_id = note_id,
--- 				target_note = l.target_note,
--- 				target_anchor = l.target_anchor,
--- 				context = l.context,
--- 				start_line = l.loc.start.line,
--- 				start_char = l.loc.start.character,
--- 				end_line = l.loc.finish.line,
--- 				end_char = l.loc.finish.character,
--- 			}
--- 		end)
---
--- 		Q.batch_insert(self.conn, "tags", nb.tags, function(t)
--- 			return { note_id = note_id, tag = t.tag }
--- 		end)
---
--- 		Q.batch_insert(self.conn, "tasks", nb.tasks, function(t)
--- 			return {
--- 				note_id = note_id,
--- 				line = t.line,
--- 				content = t.content,
--- 				status = t.status,
--- 			}
--- 		end)
---
--- 		assert(self.conn:eval("COMMIT;"), "failed to commit")
---
--- 		return note_id
--- 	end)
---
--- 	if not status then
--- 		notify.error("failed to save note: " .. tostring(result), self.silent)
--- 		return nil
--- 	end
---
--- 	nb.id = result
---
--- 	return nb
--- end

return Note

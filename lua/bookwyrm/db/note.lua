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

--- Gets the note by its relative path within a notebook.
---
--- @param nb_id integer # The notebook id
--- @param relative_path string # The relative path within the notebook
--- @return BookwyrmNote?
function Note:get_by_path(nb_id, relative_path)
	local status, result = pcall(function()
		local rows = self.conn:select("notes", {
			where = { notebook_id = nb_id, relative_path = relative_path },
		})
		assert(rows and #rows > 0, "note not found")
		return rows[1]
	end)

	if not status then
		return nil
	end

	return result
end

--- Deletes a note and all its associated data (via CASCADE).
---
--- @param id integer # The note id to delete
--- @return boolean # If the operation was successful
function Note:delete(id)
	local status, err = pcall(function()
		--- @diagnostic disable-next-line assign-type-mismatch
		assert(self.conn:delete("notes", { id = id }), "note delete failed")
	end)

	if not status then
		notify.error("failed to delete note: " .. tostring(err), self.silent)
		return false
	end

	return true
end

--- Lists all notes in a notebook.
---
--- @param nb_id integer # The notebook id
--- @return BookwyrmNote[]
function Note:list_by_notebook(nb_id)
	return self:list(nb_id)
end

--- Lists all notes.
---
--- @param nb_id integer? # The id of the notebook to search in, defaults to all notebooks.
--- @return BookwyrmNote[]
function Note:list(nb_id)
	local query = nb_id and { where = { notebook_id = nb_id } }

	local status, result = pcall(function()
		--- @diagnostic disable-next-line param-type-mismatch
		local rows = self.conn:select("notes", query)
		assert(rows, "could not list notes")

		return rows
	end)

	if not status then
		notify.error(tostring(result), self.silent)
		return {}
	end

	return result
end

--- Upserts a note (insert or update) along with all its associated data in a
--- single transaction.
---
--- @param nb_id integer # The id of the notebook to save the note to.
--- @param note BookwyrmNote # The note to save
--- @return BookwyrmNote?
function Note:upsert_note(nb_id, note)
	local status, result = pcall(function()
		assert(self.conn:eval("BEGIN TRANSACTION;"), "failed to begin transaction")

		local rows = self.conn:eval(
			[[
      INSERT INTO notes (notebook_id, relative_path, title, fsize, mtime)
      VALUES (:nb_id, :relative_path, :title, :fsize, :mtime)
      ON CONFLICT(notebook_id, relative_path) DO UPDATE SET
        title  = excluded.title,
        fsize  = excluded.fsize,
        mtime  = excluded.mtime
      RETURNING id
    ]],
			{
				nb_id = nb_id,
				relative_path = note.relative_path,
				title = note.title,
				fsize = note.fsize,
				mtime = note.mtime,
			}
		)

		if not rows or #rows < 1 then
			error("note upsert failed")
		end

		local note_id = rows[1].id

		assert(self.conn:delete("aliases", { note_id = note_id }), "failed to delete aliases")
		assert(self.conn:delete("anchors", { note_id = note_id }), "failed to delete anchors")
		assert(self.conn:delete("links", { note_id = note_id }), "failed to delete links")
		assert(self.conn:delete("tags", { note_id = note_id }), "failed to delete tags")
		assert(self.conn:delete("tasks", { note_id = note_id }), "failed to delete tasks")

		Q.batch_insert(self.conn, "aliases", note.aliases, function(a)
			return { note_id = note_id, alias = a.alias }
		end)

		Q.batch_insert(self.conn, "anchors", note.anchors, function(a)
			return {
				note_id = note_id,
				anchor_id = a.anchor_id,
				content = a.content,
				type = a.type,
				start_line = a.loc.start.line,
				start_char = a.loc.start.character,
				end_line = a.loc.finish.line,
				end_char = a.loc.finish.character,
			}
		end)

		Q.batch_insert(self.conn, "links", note.links, function(l)
			return {
				note_id = note_id,
				target_note = l.target_note,
				target_anchor = l.target_anchor,
				context = l.context,
				start_line = l.loc.start.line,
				start_char = l.loc.start.character,
				end_line = l.loc.finish.line,
				end_char = l.loc.finish.character,
			}
		end)

		Q.batch_insert(self.conn, "tags", note.tags, function(t)
			return { note_id = note_id, tag = t.tag }
		end)

		Q.batch_insert(self.conn, "tasks", note.tasks, function(t)
			return {
				note_id = note_id,
				line = t.line,
				content = t.content,
				status = t.status,
			}
		end)

		assert(self.conn:eval("COMMIT;"), "failed to commit")

		return note_id
	end)

	if not status then
		self.conn:eval("ROLLBACK;")
		notify.error("failed to save note: " .. tostring(result), self.silent)
		return nil
	end

	note.id = result

	return note
end

--- Resolves a link alias to the matching note within a notebook.
---
--- @param nb_id integer # The notebook id to search within
--- @param alias string  # The alias text (matched case-insensitively)
--- @return BookwyrmNote?  # The matching note, or nil
function Note:resolve_by_alias(nb_id, alias)
	local status, result = pcall(function()
		local rows = self.conn:eval(
			[[
      SELECT n.* FROM aliases a
      JOIN notes n ON a.note_id = n.id
      WHERE n.notebook_id = :nb_id AND lower(a.alias) = :alias
      LIMIT 1
    ]],
			{ nb_id = nb_id, alias = alias:lower() }
		)
		assert(rows and #rows > 0)
		return rows[1]
	end)

	if not status then
		return nil
	end

	return result
end

--- Resolves a note title to the matching note within a notebook.
---
--- @param nb_id integer # The notebook id to search within
--- @param title string  # The title (matched case-insensitively)
--- @return BookwyrmNote?  # The matching note, or nil
function Note:resolve_by_title(nb_id, title)
	local status, result = pcall(function()
		local rows = self.conn:eval(
			[[
      SELECT * FROM notes
      WHERE notebook_id = :nb_id AND lower(title) = :title
      LIMIT 1
    ]],
			{ nb_id = nb_id, title = title:lower() }
		)
		assert(rows and #rows > 0)
		return rows[1]
	end)

	if not status then
		return nil
	end

	return result
end

return Note

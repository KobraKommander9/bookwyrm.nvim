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

--- Inserts a new note record (without associated data).
---
--- @param nb_id integer # The notebook id
--- @param note BookwyrmNote # The note to insert
--- @return integer? # The new note id, if successful
function Note:insert(nb_id, note)
	local status, result = pcall(function()
		local rows = self.conn:eval(
			[[
      INSERT INTO notes (notebook_id, relative_path, title, fsize, mtime)
      VALUES (:nb_id, :relative_path, :title, :fsize, :mtime)
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
		assert(rows and #rows > 0, "note insert failed")
		return rows[1].id
	end)

	if not status then
		notify.error("failed to insert note: " .. tostring(result), self.silent)
		return nil
	end

	return result
end

--- Updates an existing note record.
---
--- @param id integer # The note id to update
--- @param fields table # Fields to update (title, fsize, mtime)
--- @return boolean # If the operation was successful
function Note:update(id, fields)
	local status, err = pcall(function()
		assert(
			self.conn:update("notes", {
				where = { id = id },
				set = fields,
			}),
			"note update failed"
		)
	end)

	if not status then
		notify.error("failed to update note: " .. tostring(err), self.silent)
		return false
	end

	return true
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

--- Saves a note (upsert) along with all its associated data in a transaction.
---
--- @param nb_id integer # The id of the notebook to save the note to.
--- @param nb BookwyrmNote # The note to save
--- @return BookwyrmNote?
function Note:save(nb_id, nb)
	local status, result = pcall(function()
		return Q.upsert_note(self.conn, nb_id, nb)
	end)

	if not status then
		notify.error("failed to save note: " .. tostring(result), self.silent)
		return nil
	end

	nb.id = result

	return nb
end

return Note

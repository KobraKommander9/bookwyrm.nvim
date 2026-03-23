local M = {}

--- Batch-inserts a list of items into a table.
---
--- @param db sqlite_db
--- @param table_name string
--- @param items table[]
--- @param mapper function
function M.batch_insert(db, table_name, items, mapper)
	items = items or {}
	if #items == 0 then
		return
	end

	local data = {}
	for _, item in ipairs(items) do
		table.insert(data, mapper(item))
	end

	if not db:insert(table_name, data) then
		error("batch insert failed for " .. table_name)
	end
end

--- Upserts a note along with its aliases, anchors, links, tags, and tasks in a
--- single transaction. Returns the note id on success, or raises on failure.
---
--- @param db sqlite_db
--- @param nb_id integer
--- @param note BookwyrmNote
--- @return integer # The note id
function M.upsert_note(db, nb_id, note)
	assert(db:eval("BEGIN TRANSACTION;"), "failed to begin transaction")

	local rows = db:eval(
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

	assert(db:delete("aliases", { note_id = note_id }), "failed to delete aliases")
	assert(db:delete("anchors", { note_id = note_id }), "failed to delete anchors")
	assert(db:delete("links", { note_id = note_id }), "failed to delete links")
	assert(db:delete("tags", { note_id = note_id }), "failed to delete tags")
	assert(db:delete("tasks", { note_id = note_id }), "failed to delete tasks")

	M.batch_insert(db, "aliases", note.aliases, function(a)
		return { note_id = note_id, alias = a.alias }
	end)

	M.batch_insert(db, "anchors", note.anchors, function(a)
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

	M.batch_insert(db, "links", note.links, function(l)
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

	M.batch_insert(db, "tags", note.tags, function(t)
		return { note_id = note_id, tag = t.tag }
	end)

	M.batch_insert(db, "tasks", note.tasks, function(t)
		return {
			note_id = note_id,
			line = t.line,
			content = t.content,
			status = t.status,
		}
	end)

	assert(db:eval("COMMIT;"), "failed to commit")

	return note_id
end

return M

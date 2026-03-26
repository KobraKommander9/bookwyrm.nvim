--- @diagnostic disable: missing-fields

--- @class BookwyrmNotebookDB
--- @field conn sqlite_db
--- @field silent boolean?
local Notebook = {}

local notify = require("bookwyrm.util.notify")

Notebook.__index = Notebook
Notebook.__tostring = function()
	return "Notebook"
end

--- Creates the notebook db helper.
---
--- @param conn sqlite_db # The sqlite connection
--- @param silent boolean? # If the operations should be silent
--- @return BookwyrmNotebookDB
function Notebook.new(conn, silent)
	return setmetatable({
		conn = conn,
		silent = silent,
	}, Notebook)
end

--- Deletes the notebook from the db.
---
--- @param id integer # The notebook id
--- @return BookwyrmBook? # The deleted notebook if successful
function Notebook:delete(id)
	local status, result = pcall(function()
		local rows = self.conn:select("notebooks", { where = { id = id } })
		assert(rows and #rows > 0, "could not find notebook")

		--- @diagnostic disable-next-line assign-type-mismatch
		assert(self.conn:delete("notebooks", { id = id }))

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
function Notebook:get(id)
	local status, result = pcall(function()
		local rows = self.conn:select("notebooks", { where = { id = id } })
		assert(rows and #rows == 1)
		return rows[1]
	end)

	if not status then
		return nil
	end

	return result
end

--- Gets the notebook whose root contains the provided path.
---
--- @param path string # The path to check for
--- @return BookwyrmBook?
function Notebook:get_by_path(path)
	local status, result = pcall(function()
		local rows = self.conn:eval(
			[[
      SELECT * FROM notebooks
      WHERE :path || '/' LIKE root_path || '%'
      ORDER BY LENGTH(root_path) DESC
      LIMIT 1
    ]],
			{ path = path }
		)
		assert(rows and #rows > 0)

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
function Notebook:get_default()
	local status, result = pcall(function()
		local rows = self.conn:select("notebooks", { where = { is_default = 1 } })
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
function Notebook:list()
	local status, result = pcall(function()
		--- @diagnostic disable-next-line missing-parameter
		local rows = self.conn:select("notebooks")
		assert(rows, "could not list notebooks")

		return rows
	end)

	if not status then
		notify.error(tostring(result), self.silent)
		return {}
	end

	return result
end

--- Gets the specified notebook by id.
---
--- Alias for `get` to match the standard CRUD naming convention.
---
--- @param id integer # The notebook id
--- @return BookwyrmBook?
function Notebook:get_by_id(id)
	return self:get(id)
end

--- Inserts a new notebook record.
---
--- @param nb BookwyrmBook # The notebook to insert
--- @return integer? # The id of the created notebook, if successful
function Notebook:insert(nb)
	local success, id = self.conn:insert("notebooks", {
		priority = nb.priority,
		root_path = nb.root_path,
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
function Notebook:rename(title, id)
	return self.conn:update("notebooks", {
		where = { id = id },
		set = { title = title },
	})
end

--- Sets the default notebook.
---
--- @param id integer # The id of the notebook to set as default
--- @return boolean # If the operation was a success.
function Notebook:set_default(id)
	local status, err = pcall(function()
		assert(self.conn:eval("BEGIN TRANSACTION;"), "failed to begin transaction")
		assert(self.conn:eval("UPDATE notebooks SET is_default = 0 WHERE is_default = 1;"))
		assert(self.conn:eval("UPDATE notebooks SET is_default = 1 WHERE id = :id;", { id = id }))
		assert(self.conn:eval("COMMIT;"), "failed to commit transaction")
	end)

	if not status then
		self.conn:eval("ROLLBACK;")
		notify.error("could not set default notebook: " .. tostring(err))
		return false
	end

	return true
end

return Notebook

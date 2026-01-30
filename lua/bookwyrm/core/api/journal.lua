--- @class BookwyrmJournalAPI
local M = {}

local notify = require("bookwyrm.util.notify")
local paths = require("bookwyrm.util.paths")
local state = require("bookwyrm.core.state")

--- @class BookwyrmJournalAPI.CreateNoteOpts
--- @field open true|"edit"|"vsplit"|"split"? # If true, open note

--- Creates a new note in the active notebook. Returns the created note.
---
--- @param title string # The name of the note
--- @param opts BookwyrmJournalAPI.CreateNoteOpts? # Create note opts
--- @return BookwyrmNote?
function M.create_note(title, opts)
	opts = opts or {}

	if not state.nb then
		return nil
	end

	if title == "" then
		notify.error("note title required", state.cfg.silent)
		return nil
	end

	local slug = title:gsub("%s+", "-"):gsub("[^%w%-]", ""):lower()
	local filename = slug .. ".md"
	local full_path = paths.normalize(state.nb.book.path .. "/" .. filename)

	local nb = state.nb:get_for_path(full_path)
	if nb then
		return nb
	end

	--- @diagnostic disable-next-line missing-fields
	nb = {
		path = full_path,
		title = title,
	}

	local f = io.open(full_path, "w")
	if f then
		f:write("---\n")
		f:write("title: " .. title .. "\n")
		f:write("---\n\n")
		f:close()
	end

	nb = state.nb:save(nb) --[[@as BookwyrmNote]]
	if not nb then
		notify.warn("failed to sync new note")
	end

	if opts.open then
		vim.cmd((opts.open == true and "vsplit" or opts.open) .. " " .. full_path)
	end

	return nb
end

--- Deletes the specified note.
---
--- @param id integer # The id of the note to delete
function M.delete_note(id)
	if not state.nb then
		return
	end

	notify.error("delete_note unimplemented")
end

--- Lists all notes in the active notebook.
---
--- @return BookwyrmNote[]
function M.list_notes()
	if not state.nb then
		return {}
	end

	return state.nb:list()
end

--- Syncs the notebook with the filesystem.
---
--- @param force boolean? # If true will force the sync.
function M.sync_notebook(force)
	if not state.nb then
		return
	end

	local scan_dir = state.nb.book.path
	local disk_files = {}

	local notes = state.nb:list()

	local note_map = {}
	for _, note in ipairs(notes) do
		note_map[note.path] = note
	end

	local function scan(path, cb)
		vim.uv.fs_scandir(path, function(err, fd)
			if err then
				return
			end

			while true do
				local name, type = vim.uv.fs_scandir_next(fd)
				if not name then
					break
				end

				local full_path = path .. "/" .. name
				if type == "directory" then
					scan(full_path, cb)
				elseif type == "file" and name:match("%.md$") then
					local stat = vim.uv.fs_stat(full_path)
					if stat then
						disk_files[full_path] = stat.mtime.sec
					end
				end
			end

			cb()
		end)
	end

	scan(scan_dir, function()
		vim.schedule(function()
			local to_parse = {}
			local to_delete = {}

			for path, mtime in pairs(disk_files) do
				local note = note_map[path]
				if not note or note.mtime ~= mtime then
					table.insert(to_parse, { path = path, mtime = mtime })
				end
			end

			for path, entry in pairs(note_map) do
				if not disk_files[path] then
					table.insert(to_delete, entry.id)
				end
			end

			process_sync_queue(to_parse, to_delete)
		end)
	end)
end

return M

if vim.g.loaded_bookwyrm then
	return
end
vim.g.loaded_bookwyrm = true

vim.api.nvim_create_user_command("BookwyrmSync", function()
	require("bookwyrm").api.sync()
end, { desc = "Sync active notebook with filesystem" })

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

vim.api.nvim_create_user_command("BookwyrmNotebookDelete", function()
	require("bookwyrm").api.unregister_notebook()
end, { desc = "Delete active Bookwyrm notebook" })

vim.api.nvim_create_user_command("BookwyrmNotebookRegister", function()
	local path = vim.fn.getcwd()

	vim.ui.input({
		prompt = "Enter Notebook Title: ",
		default = vim.fn.fnamemodify(path, ":t"),
	}, function(input)
		if input then
			require("bookwyrm").api.register_notebook({ path = path, title = input })
		end
	end)
end, { desc = "Register current directory as a Bookwyrm notebook" })

vim.api.nvim_create_user_command("BookwyrmNotebookRename", function()
	local path = vim.fn.getcwd()

	vim.ui.input({
		prompt = "Enter Notebook Title: ",
		default = vim.fn.fnamemodify(path, ":t"),
	}, function(input)
		if input and input ~= "" then
			require("bookwyrm").api.rename_notebook(input)
		end
	end)
end, { desc = "Rename active Bookwyrm notebook" })

vim.api.nvim_create_user_command("BookwyrmNotebookSetDefault", function()
	require("bookwyrm").api.set_default_notebook()
end, { desc = "Sets active notebook as default" })

-------------------------------------------------------------------------------
--- Notes
-------------------------------------------------------------------------------

vim.api.nvim_create_user_command("BookwyrmNoteCreate", function()
	vim.ui.input({
		prompt = "Enter Note Title: ",
	}, function(title)
		if title and title ~= "" then
			local api = require("bookwyrm").api
			local path = api.capture_note({}, { path = title })
			if path then
				api.open(path)
			end
		end
	end)
end, { desc = "Create note in active notebook" })

vim.api.nvim_create_user_command("BookwyrmCapture", function()
	require("bookwyrm").api.capture_journal()
end, { desc = "Open journal capture floating window for stream-of-thought notes" })

-------------------------------------------------------------------------------
--- Pickers
-------------------------------------------------------------------------------

vim.api.nvim_create_user_command("BookwyrmFind", function()
	local api = require("bookwyrm").api
	local notify = require("bookwyrm.util.notify")
	local notes = api.list_notes()
	if vim.tbl_isempty(notes) then
		notify.info("No notes found in active notebook")
		return
	end

	local nb = api.get_active_notebook(true)

	vim.ui.select(notes, {
		prompt = "Find Note",
		format_item = function(note)
			return note.title
		end,
	}, function(note)
		if note and nb then
			api.open(nb.root_path .. "/" .. note.relative_path)
		end
	end)
end, { desc = "Find a note in the active notebook" })

vim.api.nvim_create_user_command("BookwyrmFindNotebook", function()
	local api = require("bookwyrm").api
	local notify = require("bookwyrm.util.notify")
	local notebooks = api.list_notebooks()
	if vim.tbl_isempty(notebooks) then
		notify.info("No notebooks registered")
		return
	end

	vim.ui.select(notebooks, {
		prompt = "Find Notebook",
		format_item = function(nb)
			return nb.title
		end,
	}, function(nb)
		if nb then
			api.set_active_notebook(nb.id)
		end
	end)
end, { desc = "Switch active notebook" })

vim.api.nvim_create_user_command("BookwyrmBacklinks", function()
	local api = require("bookwyrm").api
	local notify = require("bookwyrm.util.notify")
	local file_path = vim.api.nvim_buf_get_name(0)
	local backlinks = api.get_backlinks(file_path)

	if vim.tbl_isempty(backlinks) then
		notify.info("No backlinks found for current buffer")
		return
	end

	vim.ui.select(backlinks, {
		prompt = "Backlinks",
		format_item = function(link)
			return link.source_title
		end,
	}, function(link)
		if link then
			api.open(link.source_path)
		end
	end)
end, { desc = "Show backlinks for the current buffer" })

if vim.g.loaded_bookwyrm then
	return
end
vim.g.loaded_bookwyrm = true

vim.api.nvim_create_user_command("BookwyrmSync", function()
	require("bookwyrm").api.sync()
end, { desc = "Sync active notebook with filesystem" })

vim.api.nvim_create_user_command("BookwyrmReset", function()
	require("bookwyrm").api.reset()
end, { desc = "Drop and re-scan the active notebook database" })

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

vim.api.nvim_create_user_command("BookwyrmNotebookDelete", function()
	require("bookwyrm").api.delete_notebook()
end, { desc = "Delete active Bookwyrm notebook" })

vim.api.nvim_create_user_command("BookwyrmNotebookRegister", function()
	vim.ui.input({
		prompt = "Enter Notebook Path: ",
		default = vim.fn.getcwd(),
	}, function(path)
		if not path then
			return
		end

		vim.ui.input({
			prompt = "Enter Notebook Title: ",
			default = vim.fn.fnamemodify(path, ":t"),
		}, function(input)
			if input then
				require("bookwyrm").api.register_notebook({ path = path, title = input })
			end
		end)
	end)
end, { desc = "Register a Bookwyrm notebook" })

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
	require("bookwyrm").api.capture({ tname = "journal" })
end, { desc = "Open journal capture floating window for stream-of-thought notes" })

-------------------------------------------------------------------------------
--- Pickers
-------------------------------------------------------------------------------

vim.api.nvim_create_user_command("BookwyrmFind", function()
	local mini_ok = pcall(require, "mini.pick")
	if mini_ok then
		require("bookwyrm.pickers.mini").find_notes()
		return
	end

	local api = require("bookwyrm").api
	local notes = api.list_notes()
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
	local mini_ok = pcall(require, "mini.pick")
	if mini_ok then
		require("bookwyrm.pickers.mini").find_notebooks()
		return
	end

	local api = require("bookwyrm").api
	local notebooks = api.list_notebooks()

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
	local mini_ok = pcall(require, "mini.pick")
	if mini_ok then
		require("bookwyrm.pickers.mini").find_backlinks()
		return
	end

	local api = require("bookwyrm").api
	local file_path = vim.api.nvim_buf_get_name(0)
	local backlinks = api.get_backlinks(file_path)

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

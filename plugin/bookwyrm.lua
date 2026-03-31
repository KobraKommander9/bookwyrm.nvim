if vim.g.loaded_bookwyrm then
	return
end
vim.g.loaded_bookwyrm = true

vim.api.nvim_create_user_command("BookwyrmReset", function()
	require("bookwyrm").api.reset()
end, { desc = "Drop and re-scan the active notebook database" })

vim.api.nvim_create_user_command("BookwyrmSync", function()
	require("bookwyrm").api.sync()
end, { desc = "Sync active notebook with filesystem" })

-------------------------------------------------------------------------------
--- Notebooks
-------------------------------------------------------------------------------

vim.api.nvim_create_user_command("BookwyrmNotebookDelete", function()
	local bookwyrm = require("bookwyrm")

	local mini_ok = pcall(require, "mini.pick")
	if mini_ok then
		bookwyrm.pickers.mini.find_notebooks({
			action = function(nb)
				bookwyrm.api.delete_notebook(nb.id)
			end,
		})
		return
	end

	local notebooks = bookwyrm.api.list_notebooks()

	vim.ui.select(notebooks, {
		prompt = "Find Notebook",
		format_item = function(nb)
			return nb.title
		end,
	}, function(nb)
		if nb then
			bookwyrm.api.delete_notebook(nb.id)
		end
	end)
end, { desc = "Delete notebook" })

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

vim.api.nvim_create_user_command("BookwyrmNotebookSwitch", function()
	local bookwyrm = require("bookwyrm")

	local mini_ok = pcall(require, "mini.pick")
	if mini_ok then
		bookwyrm.pickers.mini.find_notebooks()
		return
	end

	local notebooks = bookwyrm.api.list_notebooks()

	vim.ui.select(notebooks, {
		prompt = "Find Notebook",
		format_item = function(nb)
			return nb.title
		end,
	}, function(nb)
		if nb then
			bookwyrm.api.set_active_notebook(nb.id)
		end
	end)
end, { desc = "Switch active notebook" })

-------------------------------------------------------------------------------
--- Notes
-------------------------------------------------------------------------------

vim.api.nvim_create_user_command("BookwyrmNoteBacklinks", function()
	local bookwyrm = require("bookwyrm")

	local mini_ok = pcall(require, "mini.pick")
	if mini_ok then
		bookwyrm.pickers.mini.find_backlinks()
		return
	end

	local file_path = vim.api.nvim_buf_get_name(0)
	local backlinks = bookwyrm.api.get_backlinks(file_path)

	vim.ui.select(backlinks, {
		prompt = "Backlinks",
		format_item = function(link)
			return link.source_title
		end,
	}, function(link)
		if link then
			bookwyrm.api.open(link.source_path)
		end
	end)
end, { desc = "Show backlinks for the current buffer" })

vim.api.nvim_create_user_command("BookwyrmNoteCapture", function()
	require("bookwyrm").api.capture()
end, { desc = "Open capture floating window" })

vim.api.nvim_create_user_command("BookwyrmNoteSearch", function()
	local bookwyrm = require("bookwyrm")

	local mini_ok = pcall(require, "mini.pick")
	if mini_ok then
		bookwyrm.pickers.mini.find_notes()
		return
	end

	local notes = bookwyrm.api.list_notes()
	local nb = bookwyrm.api.get_active_notebook(true)

	vim.ui.select(notes, {
		prompt = "Find Note",
		format_item = function(note)
			return note.title
		end,
	}, function(note)
		if note and nb then
			bookwyrm.api.open(nb.root_path .. "/" .. note.relative_path)
		end
	end)
end, { desc = "Find note" })

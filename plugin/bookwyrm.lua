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
	require("bookwyrm").api.capture()
end, { desc = "Open quick capture floating window" })

if vim.g.loaded_bookwyrm then
	return
end
vim.g.loaded_bookwyrm = true

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
end, { desc = "Delete active Bookwyrm notebook" })

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
			require("bookwyrm").api.create_note(title, { open = true })
		end
	end)
end, { desc = "Create note in active notebook" })

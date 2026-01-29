if vim.g.loaded_bookwyrm then
	return
end
vim.g.loaded_bookwyrm = true

vim.api.nvim_create_user_command("BookwyrmRegister", function()
	local path = vim.fn.getcwd()

	vim.ui.input({
		prompt = "Enter Notebook Title: ",
		default = vim.fn.fnamemodify(path, ":t"),
	}, function(input)
		require("bookwyrm").api.register_notebook({ path = path, title = input })
	end)
end, { desc = "Register current directory as a Bookwyrm notebook" })

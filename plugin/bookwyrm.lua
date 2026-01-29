if vim.g.loaded_bookwyrm then
	return
end
vim.g.loaded_bookwyrm = true

vim.api.nvim_create_user_command("BookwyrmRegister", function()
	local api = require("bookwyrm").api
	local notify = require("bookwyrm.notify")

	local path = vim.fn.getcwd()

	vim.ui.input({
		prompt = "Enter Notebook Title: ",
		default = vim.fn.fnamemodify(path, ":t"),
	}, function(input)
		if input and input ~= "" then
			api.register_notebook({ path = path, title = input })
		else
			notify.warn("Registration cancelled")
		end
	end)
end, { desc = "Register current directory as a Bookwyrm notebook" })

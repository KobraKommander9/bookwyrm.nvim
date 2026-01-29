local M = {}

local API = require("bookwyrm.api")
local Notify = require("bookwyrm.notify")

function M.setup()
	vim.api.nvim_create_user_command("BookwyrmRegister", function()
		local path = vim.fn.getcwd()

		vim.ui.input({
			prompt = "Enter Notebook Title: ",
			default = vim.fn.fnamemodify(path, ":t"),
		}, function(input)
			if input and input ~= "" then
				API.register_notebook({ path = path, title = input })
			else
				Notify.warn("Registration cancelled")
			end
		end)
	end, { desc = "Register current directory as a Bookwyrm notebook" })
end

return M

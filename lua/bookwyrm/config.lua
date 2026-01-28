local M = {}

local defaults = {
	autocmds = true,
	data_path = vim.fn.stdpath("data") .. "/bookwyrm",
	db_name = "bookwyrm.sqlite",
}

local options

setmetatable(M, {
	__index = function(_, key)
		if options == nil then
			return vim.deepcopy(defaults)[key]
		end
		return options[key]
	end,
})

local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("Bookwyrm", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		group = group,
		callback = require("bookwyrm.db").on_buf_enter,
	})
end

function M.setup(opts)
	options = vim.tbl_deep_extend("force", defaults, opts or {})
	options.data_path = require("bookwyrm.paths").normalize(options.data_path)

	if vim.fn.isdirectory(options.data_path) == 0 then
		vim.fn.mkdir(options.data_path, "p")
	end

	options.registry_path = options.data_path .. "/registry.sqlite"
	options.notebook_dir = options.data_path .. "/notebooks"

	if vim.fn.isdirectory(options.notebook_dir) == 0 then
		vim.fn.mkdir(options.notebook_dir, "p")
	end

	local db = require("bookwyrm.db")
	if not db then
		require("bookwyrm.notify").error("unable to initialize notebook registry")
		return
	end

	db.init_registry(options.registry_path)

	if options.autocmds then
		setup_autocmds()
	end
end

return M

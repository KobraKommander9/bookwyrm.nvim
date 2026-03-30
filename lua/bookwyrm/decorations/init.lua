--- Decorations entry point.
---
--- Creates one extmark namespace per decoration category and wires up the
--- BufReadPost / BufWritePost autocmds that drive re-rendering.

local M = {}

local api_mod = require("bookwyrm.api")

-- ─── Namespaces ───────────────────────────────────────────────────────────────

local NS = {}

local function ns(name)
	if not NS[name] then
		NS[name] = vim.api.nvim_create_namespace("bookwyrm_" .. name)
	end
	return NS[name]
end

-- ─── Per-category renderers ───────────────────────────────────────────────────

local categories = {
	{ name = "meta", mod = "bookwyrm.decorations.meta", needs_nb = true },
	{ name = "links", mod = "bookwyrm.decorations.links", needs_nb = true },
	{ name = "frontmatter", mod = "bookwyrm.decorations.frontmatter", needs_nb = false },
	{ name = "tags", mod = "bookwyrm.decorations.tags", needs_nb = false },
	{ name = "headings", mod = "bookwyrm.decorations.headings", needs_nb = false },
	{ name = "backlinks", mod = "bookwyrm.decorations.backlinks", needs_nb = true },
	{ name = "timestamps", mod = "bookwyrm.decorations.timestamps", needs_nb = false },
	{ name = "tasks", mod = "bookwyrm.decorations.tasks", needs_nb = false },
	{ name = "codeblocks", mod = "bookwyrm.decorations.codeblocks", needs_nb = false },
}

--- Clears all decoration namespaces for a buffer.
---
--- @param buf integer
local function clear_all(buf)
	for _, cat in ipairs(categories) do
		vim.api.nvim_buf_clear_namespace(buf, ns(cat.name), 0, -1)
	end
	-- Also unplace orphan signs
	vim.fn.sign_unplace("bookwyrm_orphan", { buffer = buf })
end

--- Renders all decorations for the given buffer, if it belongs to the active
--- notebook.  Silently skips buffers that are not part of any registered notebook.
---
--- @param buf integer
function M.render(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local path = vim.api.nvim_buf_get_name(buf)
	if not path or path == "" then
		return
	end

	-- Only decorate markdown files
	if not path:match("%.md$") then
		return
	end

	local nb = api_mod.get_notebook_by_path(path)
	if not nb then
		return
	end

	clear_all(buf)

	for _, cat in ipairs(categories) do
		local ok, renderer = pcall(require, cat.mod)
		if ok then
			local run_ok, err = pcall(function()
				if cat.needs_nb then
					renderer.render(buf, ns(cat.name), nb)
				else
					renderer.render(buf, ns(cat.name))
				end
			end)
			if not run_ok then
				-- Log but don't abort other categories
				vim.notify(
					string.format("[bookwyrm] decoration error (%s): %s", cat.name, tostring(err)),
					vim.log.levels.DEBUG
				)
			end
		end
	end
end

-- ─── Autocmd setup ────────────────────────────────────────────────────────────

--- Registers BufReadPost and BufWritePost autocmds that trigger re-rendering.
--- Should be called once from `bookwyrm.setup()`.
function M.setup()
	local group = vim.api.nvim_create_augroup("BookwyrmDecorations", { clear = true })

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			-- Defer so the buffer content is fully loaded before we scan it
			vim.schedule(function()
				M.render(ev.buf)
			end)
		end,
	})

	-- Re-render on colorscheme changes so highlights survive theme switches
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			require("bookwyrm.highlights").setup()
			-- Re-render all currently open notebook buffers
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) then
					vim.schedule(function()
						M.render(buf)
					end)
				end
			end
		end,
	})
end

return M

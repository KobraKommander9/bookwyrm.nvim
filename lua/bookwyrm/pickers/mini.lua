--- mini.pick integration for bookwyrm.nvim
---
--- Provides pre-baked pickers for notes, notebooks, and backlinks using
--- echasnovski/mini.pick. Each public function is a standalone picker action
--- that can be called directly or wired to a user command.
---
--- Usage (lazy.nvim example):
---   require("bookwyrm").setup()
---   -- Commands like :BookwyrmFind automatically use mini.pick when available.
---   -- Or call directly:
---   require("bookwyrm.pickers.mini").find_notes()
local M = {}

--- Returns true when mini.pick is available, false (and notifies) otherwise.
---
--- @return boolean
local function has_mini_pick()
	local ok = pcall(require, "mini.pick")
	if not ok then
		vim.notify("[bookwyrm] mini.pick is not installed", vim.log.levels.ERROR)
		return false
	end
	return true
end

--- Opens a mini.pick session for searching and opening notes.
---
--- Each item's display text includes the note title, aliases, and tags so
--- mini.pick's fuzzy engine can filter on all three fields.
---
--- Key mappings:
---   <CR>    Open the selected note in the current window
---   <C-l>   Insert a [[note title]] wikilink at the calling buffer's cursor
function M.find_notes()
	if not has_mini_pick() then
		return
	end

	local MiniPick = require("mini.pick")
	local api = require("bookwyrm").api
	local notify = require("bookwyrm.util.notify")

	local notes = api.list_notes()
	if vim.tbl_isempty(notes) then
		notify.info("No notes found in active notebook")
		return
	end

	-- Capture calling context before the picker takes over the window
	local caller_buf = vim.api.nvim_get_current_buf()
	local caller_cursor = vim.api.nvim_win_get_cursor(0) -- { row (1-based), col (0-based) }

	-- Build display items: title + aliases + tags so fuzzy engine searches all three
	local items = {}
	for _, note in ipairs(notes) do
		local aliases = {}
		for _, a in ipairs(note.aliases or {}) do
			table.insert(aliases, a.alias)
		end

		local tags = {}
		for _, t in ipairs(note.tags or {}) do
			table.insert(tags, t.tag)
		end

		local display = note.title
		if #aliases > 0 then
			display = display .. "  [" .. table.concat(aliases, ", ") .. "]"
		end
		if #tags > 0 then
			display = display .. "  #" .. table.concat(tags, " #")
		end

		table.insert(items, { text = display, note = note })
	end

	MiniPick.start({
		source = {
			items = items,
			name = "Bookwyrm Notes",
			choose = function(item)
				if item then
					api.open_note(item.note)
				end
			end,
		},
		mappings = {
			insert_link = {
				char = "<C-l>",
				func = function()
					local matches = MiniPick.get_picker_matches()
					local item = matches and matches.current
					if item then
						MiniPick.stop()
						-- insert_link expects cursor as { row (1-based), col (1-based) }
						api.insert_link(item.note, caller_buf, { caller_cursor[1], caller_cursor[2] + 1 })
					end
				end,
			},
		},
	})
end

--- Opens a mini.pick session for switching the active notebook.
---
--- Display text shows the notebook name followed by its root path.
---
--- Key mappings:
---   <CR>   Set the selected notebook as the active notebook
function M.find_notebooks()
	if not has_mini_pick() then
		return
	end

	local MiniPick = require("mini.pick")
	local api = require("bookwyrm").api
	local notify = require("bookwyrm.util.notify")

	local notebooks = api.list_notebooks()
	if vim.tbl_isempty(notebooks) then
		notify.info("No notebooks registered")
		return
	end

	local items = {}
	for _, nb in ipairs(notebooks) do
		table.insert(items, {
			text = nb.title .. "  " .. nb.root_path,
			notebook = nb,
		})
	end

	MiniPick.start({
		source = {
			items = items,
			name = "Bookwyrm Notebooks",
			choose = function(item)
				if item then
					api.set_active_notebook(item.notebook)
				end
			end,
		},
	})
end

--- Opens a mini.pick session showing all notes that link to the current buffer.
---
--- Display text shows the source note title and, when available, the anchor id
--- and surrounding link context.
---
--- If no backlinks exist, emits an info notification and does not open the picker.
---
--- Key mappings:
---   <CR>   Open the linking note in the current window
function M.find_backlinks()
	if not has_mini_pick() then
		return
	end

	local MiniPick = require("mini.pick")
	local api = require("bookwyrm").api
	local notify = require("bookwyrm.util.notify")

	local file_path = vim.api.nvim_buf_get_name(0)
	local backlinks = api.get_backlinks(file_path)

	if vim.tbl_isempty(backlinks) then
		notify.info("No backlinks found for current buffer")
		return
	end

	local items = {}
	for _, link in ipairs(backlinks) do
		local display = link.source_title
		if link.anchor and link.anchor ~= "" then
			display = display .. "  ^" .. link.anchor
		end
		if link.context and link.context ~= "" then
			display = display .. "  \xe2\x80\x94 " .. link.context
		end
		table.insert(items, { text = display, link = link })
	end

	MiniPick.start({
		source = {
			items = items,
			name = "Bookwyrm Backlinks",
			choose = function(item)
				if item then
					api.open(item.link.source_path)
				end
			end,
		},
	})
end

return M

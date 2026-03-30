--- Telescope extension for bookwyrm.nvim
---
--- Provides pre-baked Telescope pickers for notes, notebooks, and backlinks.
--- Load with:
---   require('telescope').load_extension('bookwyrm')
---
--- Then use the pickers via:
---   :Telescope bookwyrm find_notes
---   :Telescope bookwyrm find_notebooks
---   :Telescope bookwyrm backlinks

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	require("bookwyrm.util.notify").error("Telescope is required for bookwyrm telescope pickers")
	return {}
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

local M = {}

--- Opens a Telescope picker for searching and opening notes.
---
--- Entry display shows note title (primary), relative path and aliases/tags (secondary).
--- Fuzzy-searches across the full display string.
---
--- <CR> opens the selected note.
--- <C-l> inserts a [[note title]] wikilink at the calling buffer's cursor.
---
--- @param opts? table Telescope picker options
function M.find_notes(opts)
	opts = opts or {}

	local api = require("bookwyrm").api
	local notes = api.list_notes()

	-- Capture calling context before the picker takes over the window
	local caller_buf = vim.api.nvim_get_current_buf()
	local caller_cursor = vim.api.nvim_win_get_cursor(0) -- { row (1-based), col (0-based) }

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ remaining = true },
			{ remaining = true },
		},
	})

	local function make_display(entry)
		local secondary_parts = {}
		if entry.value.relative_path and entry.value.relative_path ~= "" then
			table.insert(secondary_parts, entry.value.relative_path)
		end
		if entry.value.aliases and #entry.value.aliases > 0 then
			local alias_strs = {}
			for _, a in ipairs(entry.value.aliases) do
				table.insert(alias_strs, a.alias)
			end
			table.insert(secondary_parts, "[" .. table.concat(alias_strs, ", ") .. "]")
		end
		if entry.value.tags and #entry.value.tags > 0 then
			local tag_strs = {}
			for _, t in ipairs(entry.value.tags) do
				table.insert(tag_strs, "#" .. t.tag)
			end
			table.insert(secondary_parts, table.concat(tag_strs, " "))
		end

		return displayer({
			entry.value.title,
			{ table.concat(secondary_parts, "  "), "TelescopeResultsComment" },
		})
	end

	local function entry_maker(note)
		local aliases = {}
		for _, a in ipairs(note.aliases or {}) do
			table.insert(aliases, a.alias)
		end
		local tags = {}
		for _, t in ipairs(note.tags or {}) do
			table.insert(tags, t.tag)
		end

		-- ordinal includes title + aliases + tags for fuzzy matching
		local ordinal = note.title
		if #aliases > 0 then
			ordinal = ordinal .. " " .. table.concat(aliases, " ")
		end
		if #tags > 0 then
			ordinal = ordinal .. " " .. table.concat(tags, " ")
		end

		return {
			value = note,
			display = make_display,
			ordinal = ordinal,
		}
	end

	pickers
		.new(opts, {
			prompt_title = "Bookwyrm Notes",
			finder = finders.new_table({
				results = notes,
				entry_maker = entry_maker,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				-- <CR>: open note
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local entry = action_state.get_selected_entry()
					if entry then
						api.open_note(entry.value)
					end
				end)

				-- <C-l>: insert [[note title]] link at calling cursor
				map({ "i", "n" }, "<C-l>", function()
					actions.close(prompt_bufnr)
					local entry = action_state.get_selected_entry()
					if entry then
						-- insert_link expects cursor as { row (1-based), col (1-based) }
						api.insert_link(entry.value, caller_buf, { caller_cursor[1], caller_cursor[2] + 1 })
					end
				end)

				return true
			end,
		})
		:find()
end

--- Opens a Telescope picker for switching the active notebook.
---
--- Entry display shows notebook name (primary) and root path (secondary).
---
--- <CR> switches to the selected notebook.
---
--- @param opts? table Telescope picker options
function M.find_notebooks(opts)
	opts = opts or {}

	local api = require("bookwyrm").api
	local notebooks = api.list_notebooks()

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ remaining = true },
			{ remaining = true },
		},
	})

	local function make_display(entry)
		return displayer({
			entry.value.title,
			{ entry.value.root_path, "TelescopeResultsComment" },
		})
	end

	pickers
		.new(opts, {
			prompt_title = "Bookwyrm Notebooks",
			finder = finders.new_table({
				results = notebooks,
				entry_maker = function(nb)
					return {
						value = nb,
						display = make_display,
						ordinal = nb.title .. " " .. nb.root_path,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local entry = action_state.get_selected_entry()
					if entry then
						api.set_active_notebook(entry.value)
					end
				end)

				return true
			end,
		})
		:find()
end

--- Opens a Telescope picker showing all notes that link to the current buffer.
---
--- Entry display shows source note title (primary) and anchor/context (secondary).
---
--- <CR> opens the linking note.
--- If no backlinks exist, shows a notification and does not open the picker.
---
--- @param opts? table Telescope picker options
function M.backlinks(opts)
	opts = opts or {}

	local api = require("bookwyrm").api
	local notify = require("bookwyrm.util.notify")
	local file_path = vim.api.nvim_buf_get_name(0)
	local backlinks = api.get_backlinks(file_path)

	if not backlinks or #backlinks == 0 then
		notify.info("No backlinks found for this buffer")
		return
	end

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ remaining = true },
			{ remaining = true },
		},
	})

	local function make_display(entry)
		local link = entry.value
		local secondary_parts = {}
		if link.anchor and link.anchor ~= "" then
			table.insert(secondary_parts, "^" .. link.anchor)
		end
		if link.context and link.context ~= "" then
			table.insert(secondary_parts, "— " .. link.context)
		end

		return displayer({
			link.source_title,
			{ table.concat(secondary_parts, "  "), "TelescopeResultsComment" },
		})
	end

	pickers
		.new(opts, {
			prompt_title = "Bookwyrm Backlinks",
			finder = finders.new_table({
				results = backlinks,
				entry_maker = function(link)
					local ordinal = link.source_title
					if link.anchor and link.anchor ~= "" then
						ordinal = ordinal .. " " .. link.anchor
					end
					return {
						value = link,
						display = make_display,
						ordinal = ordinal,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local entry = action_state.get_selected_entry()
					if entry then
						api.open(entry.value.source_path)
					end
				end)

				return true
			end,
		})
		:find()
end

return telescope.register_extension({
	exports = {
		find_notes = M.find_notes,
		find_notebooks = M.find_notebooks,
		backlinks = M.backlinks,
	},
})

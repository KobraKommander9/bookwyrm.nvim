local M = {}

--- This parses anchors from the given buffer's lines and appends them to the
--- data. Anchors can be of 3 main formats:
---   - Multiline range: \[#start:anchor-id\] ... \[#end:anchor-id\]
---   - Span: \[Content\]{#anchor-id}
---   - Block: {#anchor-id}
---
--- Note: block anchors will anchor the text from the start of the paragraph,
---   or line if not found, up until the anchor itself.
---
--- @param bufnr integer # The buffer number
--- @param lines string[] # The buffer lines
--- @param data BookwyrmNote # The note
local function parse_anchors(bufnr, lines, data)
	local active_starts = {}

	for i, line in ipairs(lines) do
		local row = i - 1

		for start_col, id, end_col in line:gmatch("()%[#start:([%w%-_]+)%]()") do
			active_starts[id] = {
				row = row,
				col = start_col - 1,
				end_col = end_col - 1,
			}
		end

		for start_col, id, end_col in line:gmatch("()%[#end:([%w%-_]+)%]()") do
			local start_data = active_starts[id]
			if start_data then
				local lines_content =
					vim.api.nvim_buf_get_text(bufnr, start_data.row, start_data.end_col, row, start_col - 1, {})

				table.insert(data.anchors, {
					anchor_id = id,
					content = table.concat(lines_content, "\n"),
					loc = {
						start = { line = start_data.row, character = start_data.col },
						finish = { line = row, character = end_col - 1 },
					},
				})

				active_starts[id] = nil
			end
		end
	end

	for i, line in ipairs(lines) do
		local row = i - 1

		-- mask extracted range anchors
		local temp_line = line:gsub("%[#start:[%w%-_]+%]", function(m)
			return string.rep(" ", #m)
		end)

		temp_line = temp_line:gsub("%[#end:[%w%-_]+%]", function(m)
			return string.rep(" ", #m)
		end)

		-- basic span: [...]{#id}
		temp_line = temp_line:gsub("()(%b[])%s*{#([%w%-_]+)}()", function(start_col, content, id, end_col)
			table.insert(data.anchors, {
				anchor_id = id,
				content = content:sub(2, -2), -- strip [ and ]
				loc = {
					start = { line = row, character = start_col - 1 },
					finish = { line = row, character = end_col - 1 },
				},
			})

			-- return a string of spaces equal to the length of the entire match
			return string.rep(" ", end_col - start_col)
		end)

		-- block anchor: <beginning of block>^id
		for start_col, id, end_col in temp_line:gmatch("(){#([%w%-_]+)}()") do
			local final_start = { line = row, character = 0 }
			local block_text = temp_line:sub(1, start_col - 1)

			local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, start_col - 1 } })
			if node then
				--- @type TSNode?
				local curr = node

				while curr do
					local type = curr:type()

					if type:find("paragraph") or type:find("section") or type:find("list_item") then
						local s_row, s_col, _, _ = curr:range()
						final_start = { line = s_row, character = s_col }

						local content_lines = {}
						if not (s_row == row and s_col == start_col - 1) then
							content_lines = vim.api.nvim_buf_get_text(bufnr, s_row, s_col, row, start_col - 1, {})
						end

						if #content_lines > 0 then
							block_text = table.concat(content_lines, "\n")
						end

						break
					end

					curr = curr:parent()
				end
			end

			table.insert(data.anchors, {
				anchor_id = id,
				content = block_text,
				loc = {
					start = final_start,
					finish = { line = row, character = end_col - 1 },
				},
			})
		end
	end
end

--- This parses links from the given lines and appends them to the data.
--- Links are expected to be of the form \[\[Note#Anchor|Alias\]\], where
--- each part is optional.
---
--- @param lines string[] # The lines to parse
--- @param data BookwyrmNote # The parsed data
local function parse_links(lines, data)
	local id_pattern = "^[%w%-_]+$"

	for i, line in ipairs(lines) do
		for start_pos, raw_link, end_pos in line:gmatch("()%[%[(.-)%]%]()") do
			local target, alias = raw_link:match("([^|]+)|?(.*)")
			target = target or ""

			local note, anchor = target:match("([^#]*)#?(.*)")

			note = vim.trim(note or "")
			anchor = vim.trim(anchor or "")

			if anchor ~= "" and not anchor:match(id_pattern) then
				anchor = ""
			end

			table.insert(data.links, {
				alias = (alias and alias ~= "") and vim.trim(alias) or nil,
				context = line,
				loc = {
					start = { line = i - 1, character = start_pos - 1 },
					finish = { line = i - 1, character = end_pos - 1 },
				},
				target_anchor = anchor ~= "" and anchor or nil,
				target_note = note ~= "" and note or nil,
			})
		end
	end
end

--- This parses the buffer to produce a BookwyrmNote artifact.
---
--- @param bufnr integer # The buffer number of the buffer being parsed
--- @return BookwyrmNote?
function M.parse_buffer(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local path = vim.api.nvim_buf_get_name(bufnr)

	local data = {
		aliases = {},
		anchors = {},
		links = {},
		tags = {},
		tasks = {},

		path = path,
		title = vim.fn.fnamemodify(path, ":t:r"),
	}

	parse_anchors(bufnr, lines, data)
	parse_links(lines, data)

	return data
end

return M

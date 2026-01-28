local M = {}

--- Parses anchors from the given line and appends them to the data. Anchors
--- can be of 3 main formats, with the ids consisting of alphanumeric, hyphen,
--- or undescore characters:
---   - Multiline range: \[^start:anchor-id\] ... \[^end:anchor-id\]
---   - Span: \[Content\]^anchor-id
---   - Block: ^anchor-id
---
--- Note: block anchors will anchor the text from the start of the paragraph,
---   or line if not found, up until the anchor itself.
---
--- @param bufnr integer # The buffer number
--- @param linenr integer # The line number (0 indexed)
--- @param line string # The line to parse
--- @param active_starts table # The list of currently active ranges
--- @param data BookwyrmNote # The note to populate
local function parse_anchors(bufnr, linenr, line, active_starts, data)
	-- multiline range anchors
	line = line:gsub("()%[%^start:([%w%-_]+)%]()", function(start_col, id, end_col)
		active_starts[id] = {
			row = linenr,
			col = start_col - 1,
			end_col = end_col - 1,
		}

		return string.rep(" ", end_col - start_col)
	end)

	line = line:gsub("()%[%^end:([%w%-_]+)%]()", function(start_col, id, end_col)
		local start_data = active_starts[id]
		if start_data then
			local lines =
				vim.api.nvim_buf_get_text(bufnr, start_data.row, start_data.end_col, linenr, start_col - 1, {})

			table.insert(data.anchors, {
				anchor_id = id,
				content = table.concat(lines, "\n"),
				loc = {
					start = { line = start_data.row, character = start_data.col },
					finish = { line = linenr, character = end_col - 1 },
				},
			})

			active_starts[id] = nil
		end

		return string.rep(" ", end_col - start_col)
	end)

	-- span anchors: [...]^id
	line = line:gsub("()(%b[])%^([%w%-_]+)()", function(start_col, content, id, end_col)
		table.insert(data.anchors, {
			anchor_id = id,
			content = content:sub(2, -2), -- strip [ and ]
			loc = {
				start = { line = linenr, character = start_col - 1 },
				finish = { line = linenr, character = end_col - 1 },
			},
		})

		return string.rep(" ", end_col - start_col)
	end)

	-- block anchor: <beginning of block>^id
	for start_col, id, end_col in line:gmatch("()%s%^([%w%-_]+)()") do
		local final_start = { line = linenr, character = 0 }
		local block_text = line:sub(1, start_col - 1)

		local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { linenr, start_col - 1 } })
		if node then
			--- @type TSNode?
			local curr = node

			while curr do
				local type = curr:type()

				if type:find("paragraph") or type:find("section") or type:find("list_item") then
					local s_row, s_col, _, _ = curr:range()
					final_start = { line = s_row, character = s_col }

					local content_lines = {}
					if not (s_row == linenr and s_col == start_col - 1) then
						content_lines = vim.api.nvim_buf_get_text(bufnr, s_row, s_col, linenr, start_col - 1, {})
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
				finish = { line = linenr, character = end_col - 1 },
			},
		})
	end
end

--- Parses links from the line and appends them to the note. Links are expected
--- to be of the form \[\[Note#Anchor|Alias\]\], where each part is optional.
---
--- @param linenr integer # The line number (0 indexed)
--- @param line string # The line to parse
--- @param data BookwyrmNote # The note to populate
local function parse_links(linenr, line, data)
	local id_pattern = "^[%w%-_]+$"

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
				start = { line = linenr, character = start_pos - 1 },
				finish = { line = linenr, character = end_pos - 1 },
			},
			target_anchor = anchor ~= "" and anchor or nil,
			target_note = note ~= "" and note or nil,
		})
	end
end

--- Parses metadata from the note metadata
---
--- @param line string # The line in the metadata block
--- @param data BookwyrmNote # The note to populate
local function parse_metadata(line, data)
	local title = line:match("^title:%s*(.+)$")
	if title then
		data.title = vim.trim(title):gsub("^([\"'])(.*)%1$", "%2")
	end

	local aliases = line:match("^alias:%s*%[?(.+)%]?(.*)$") or line:match("^aliases:%s*%[?(.+)%]?(.*)$")
	if aliases then
		for a in aliases:gmatch("([^,]+)") do
			table.insert(data.aliases, {
				alias = vim.trim(a):gsub("^([\"'])(.*)%1$", "%2"),
			})
		end
	end

	local tags = line:match("^tags:%s*%[?(.+)%]?(.*)$")
	if tags then
		for t in tags:gmatch("([^,]+)") do
			table.insert(data.tags, {
				tag = vim.trim(t):gsub("^#", ""),
			})
		end
	end
end

--- Parses the buffer to produce a BookwyrmNote artifact.
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

	local inside_metadata = lines[1] == "---"
	local start = inside_metadata and 2 or 1

	local active_anchors = {}

	for i = start, #lines do
		local line = lines[i]
		if inside_metadata and line == "---" then
			inside_metadata = false
		end

		if inside_metadata then
			parse_metadata(line, data)
		else
			parse_links(i, line, data)
			parse_anchors(bufnr, i, line, active_anchors, data)
		end
	end

	return data
end

return M

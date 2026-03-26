local M = {}

--- @class ParseResult
--- @field aliases BookwyrmAlias[]
--- @field anchors BookwyrmAnchor[]
--- @field links BookwyrmLink[]
--- @field tags BookwyrmTag[]
--- @field tasks BookwyrmTask[]

--- Trims leading and trailing whitespace from a string.
--- @param s string
--- @return string
local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

--- Extracts #tagname tokens from a string.
--- @param s string
--- @return string[]
local function extract_inline_tags(s)
	local tags = {}
	for tag in s:gmatch("#([%w_%-]+)") do
		table.insert(tags, tag)
	end
	return tags
end

--- Parses a single YAML front-matter line and populates result.
--- @param line string
--- @param result ParseResult
local function parse_frontmatter_line(line, result)
	-- aliases: [a, b, c] or alias: [a, b, c]
	local aliases = line:match("^aliases:%s*%[?(.-)%]?$") or line:match("^alias:%s*%[?(.-)%]?$")
	if aliases then
		for a in aliases:gmatch("([^,]+)") do
			local alias = trim(a):gsub("^([\"'])(.*)%1$", "%2")
			if alias ~= "" then
				table.insert(result.aliases, { alias = alias })
			end
		end
		return
	end

	-- tags: [t1, t2]
	local tags = line:match("^tags:%s*%[?(.-)%]?$")
	if tags then
		for t in tags:gmatch("([^,]+)") do
			local tag = trim(t):gsub("^#", "")
			if tag ~= "" then
				table.insert(result.tags, { tag = tag })
			end
		end
	end
end

--- Parses wiki-style links from the line, appends to result, and returns the
--- line with matched regions replaced by spaces (so downstream parsers don't
--- double-count the same text).
---
--- Supported forms:
---   [[target]]
---   [[target|alias]]
---   [[note#anchor]]
---   [[note#anchor|alias]]
---
--- @param linenr integer # 0-indexed line number
--- @param line string
--- @param result ParseResult
--- @return string # masked line
local function parse_links(linenr, line, result)
	line = line:gsub("()%[%[(.-)%]%]()", function(start_pos, raw_link, end_pos)
		local target, alias = raw_link:match("([^|]+)|?(.*)")
		target = target or ""
		alias = (alias ~= "") and alias or nil

		local note, anchor = target:match("([^#]*)#?(.*)")
		note = trim(note or "")
		anchor = trim(anchor or "")

		if anchor ~= "" and not anchor:match("^[%w%-_]+$") then
			anchor = ""
		end

		table.insert(result.links, {
			alias = alias and trim(alias) or nil,
			loc = {
				start = { line = linenr, character = start_pos - 1 },
				finish = { line = linenr, character = end_pos - 1 },
			},
			target_anchor = anchor ~= "" and anchor or nil,
			target_note = note ~= "" and note or nil,
		})

		return string.rep(" ", end_pos - start_pos)
	end)

	return line
end

--- Parses a task line (- [ ] or - [x]) and appends to result.
--- Extracts any #tags from the task content.
---
--- @param linenr integer # 0-indexed line number
--- @param line string
--- @param result ParseResult
local function parse_task(linenr, line, result)
	local status, content = line:match("^%s*-%s*%[([%sxX])%]%s*(.*)$")
	if status then
		local tags = extract_inline_tags(content)
		table.insert(result.tasks, {
			content = trim(content),
			line = linenr,
			status = (status:lower() == "x") and 1 or 0,
			tags = tags,
		})
	end
end

--- Parses anchor markers from the (masked) line and appends to result.
--- Returns the line with anchor markers replaced by spaces.
---
--- Supported forms:
---   Range:  [^start:id] ... [^end:id]
---   Span:   [content]^id
---   Block:  ^id  (standalone or preceded by whitespace)
---
--- @param linenr integer # 0-indexed line number
--- @param lines string[] # full list of buffer lines (1-indexed)
--- @param line string # masked line
--- @param active_starts table # mutable table tracking open range anchors
--- @param result ParseResult
--- @return string # further masked line
local function parse_anchors(linenr, lines, line, active_starts, result)
	-- Range start: [^start:id]
	line = line:gsub("()%[%^start:([%w%-_]+)%]()", function(start_col, id, end_col)
		active_starts[id] = {
			row = linenr,
			col = start_col - 1,
			end_col = end_col - 1,
		}
		return string.rep(" ", end_col - start_col)
	end)

	-- Range end: [^end:id]
	line = line:gsub("()%[%^end:([%w%-_]+)%]()", function(start_col, id, end_col)
		local s = active_starts[id]
		if s then
			local parts = {}
			for row = s.row, linenr do
				local l = lines[row + 1] or ""
				if row == s.row and row == linenr then
					table.insert(parts, l:sub(s.end_col + 1, start_col - 1))
				elseif row == s.row then
					table.insert(parts, l:sub(s.end_col + 1))
				elseif row == linenr then
					table.insert(parts, l:sub(1, start_col - 1))
				else
					table.insert(parts, l)
				end
			end

			table.insert(result.anchors, {
				anchor_id = id,
				content = table.concat(parts, "\n"),
				loc = {
					start = { line = s.row, character = s.col },
					finish = { line = linenr, character = end_col - 1 },
				},
				type = "range",
			})

			active_starts[id] = nil
		end
		return string.rep(" ", end_col - start_col)
	end)

	-- Span anchor: [content]^id
	line = line:gsub("()(%b[])%^([%w%-_]+)()", function(start_col, content, id, end_col)
		table.insert(result.anchors, {
			anchor_id = id,
			content = content:sub(2, -2),
			loc = {
				start = { line = linenr, character = start_col - 1 },
				finish = { line = linenr, character = end_col - 1 },
			},
			type = "span",
		})
		return string.rep(" ", end_col - start_col)
	end)

	-- Block anchor: ^id (standalone or preceded by whitespace)
	line = line:gsub("()(.?)%^([%w%-_]+)()", function(start_col, prefix, id, end_col)
		if prefix == "" or prefix:match("%s") then
			local anchor_col = (prefix == "") and (start_col - 1) or start_col

			-- Scan backward to find the start of the paragraph (stop at blank line)
			local para_start_row = linenr
			for row = linenr - 1, 0, -1 do
				if (lines[row + 1] or ""):match("^%s*$") then
					break
				end
				para_start_row = row
			end

			local parts = {}
			for row = para_start_row, linenr do
				local l = lines[row + 1] or ""
				if row == linenr then
					table.insert(parts, l:sub(1, anchor_col))
				else
					table.insert(parts, l)
				end
			end

			table.insert(result.anchors, {
				anchor_id = id,
				content = table.concat(parts, "\n"),
				loc = {
					start = { line = para_start_row, character = 0 },
					finish = { line = linenr, character = end_col - 1 },
				},
				type = "block",
			})

			return prefix .. string.rep(" ", end_col - (start_col + #prefix))
		end

		-- Not a block anchor
		return prefix .. "^" .. id
	end)

	return line
end

--- Deduplicates tags and aliases in place.
--- @param result ParseResult
local function deduplicate(result)
	local seen_tags = {}
	local unique_tags = {}
	for _, item in ipairs(result.tags) do
		if not seen_tags[item.tag] then
			table.insert(unique_tags, item)
			seen_tags[item.tag] = true
		end
	end
	result.tags = unique_tags

	local seen_aliases = {}
	local unique_aliases = {}
	for _, item in ipairs(result.aliases) do
		if not seen_aliases[item.alias] then
			table.insert(unique_aliases, item)
			seen_aliases[item.alias] = true
		end
	end
	result.aliases = unique_aliases
end

--- Parses a list of buffer lines and returns structured data.
---
--- @param lines string[] # Buffer lines, 1-indexed (as returned by nvim_buf_get_lines)
--- @return ParseResult
function M.parse(lines)
	--- @type ParseResult
	local result = {
		links = {},
		anchors = {},
		tags = {},
		tasks = {},
		aliases = {},
	}

	local in_frontmatter = lines[1] == "---"
	local active_starts = {}

	-- When the first line is "---" we skip it (it's the delimiter, not content)
	-- and enter front-matter mode.
	local start_i = in_frontmatter and 2 or 1

	for i = start_i, #lines do
		local line = lines[i]
		local linenr = i - 1 -- 0-indexed

		if in_frontmatter and line == "---" then
			in_frontmatter = false
		elseif in_frontmatter then
			parse_frontmatter_line(line, result)
		else
			-- Inline alias:: field (Obsidian-style dataview syntax)
			local inline_alias = line:match("^alias::%s*(.+)$")
			if inline_alias then
				table.insert(result.aliases, { alias = trim(inline_alias) })
			end

			-- Tasks must be parsed before masking so patterns stay intact
			parse_task(linenr, line, result)

			-- Mask links, then parse anchors against the masked line
			local masked = parse_links(linenr, line, result)
			masked = parse_anchors(linenr, lines, masked, active_starts, result)

			-- Inline tags from the remaining (masked) content
			for _, tag in ipairs(extract_inline_tags(masked)) do
				table.insert(result.tags, { tag = tag })
			end
		end
	end

	deduplicate(result)
	return result
end

return M

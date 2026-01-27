local M = {}

--- This parses anchors from the given lines and appends them to the data.
--- The supported anchors are:
---  - Line/Span: \[text\]{#id}
---  - Block: ^id at the end of a paragraph
---  - Multiline Range: ::: {#id} ... :::
--- @param lines string[] # The lines to parse
--- @param data table # The parsed data
local function parse_anchors(lines, data)
	local in_multiline = false

	--- @type table|nil
	local current_multiline = nil

	for i, line in ipairs(lines) do
		--- check for multiline range start/end (::: {#id})
		local multi_id = line:match("^:::?%s*{(#.-)}")
		if multi_id then
			in_multiline = true
			current_multiline = { id = multi_id, start_line = i }
		elseif in_multiline and line:match("^:::?%s*$") then
			current_multiline.end_line = i
			current_multiline.type = "range"

			table.insert(data.anchors, current_multiline)

			in_multiline = false
			current_multiline = nil
		end
	end
end

--- This parses links from the given lines and appends them to the data.
--- Links are expected to be of the form [[Note|Alias#Anchor]] or
--- [[Note|Alias^Anchor]] where each part is optional.
--- @param lines string[] # The lines to parse
--- @param data table # The parsed data
local function parse_links(lines, data)
	for i, line in ipairs(lines) do
		local s = 1
		while true do
			local start_pos, end_pos, raw_link = line:find("%[%[(.-)%]%]", s)
			if not start_pos then
				break
			end

			-- 1. ([^#|]*) -> note: 0 or more chars that aren't # or |
			-- 2. #? -> optional separator
			-- 3. ([^|]*) _> anchor: 0 or more chars that aren't |

			local note, anchor = raw_link:match("([^#|]*)#?([^|]*)")
			note = vim.trim(note or "")
			anchor = vim.trim(anchor or "")

			table.insert(data.links, {
				col = end_pos,
				content = line,
				line = i - 1,
				target_anchor = anchor ~= "" and anchor or nil,
				target_note = note ~= "" and note or nil,
			})

			s = end_pos + 1
		end
	end
end

--- @param bufnr integer # Buf nr of buffer to parse
--- @return BookwyrmNote|nil
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

	parse_anchors(lines, data)
	parse_links(lines, data)

	return data
end

return M

--- Timestamp decorations: relative age appended next to `date:` frontmatter fields.

local M = {}

--- Parses a YYYY-MM-DD string into a Unix timestamp (seconds since epoch).
--- Returns nil if the format doesn't match.
---
--- @param date_str string
--- @return integer?
local function parse_date(date_str)
	local y, m, d = date_str:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
	if not y then
		return nil
	end
	return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
end

--- Returns a human-readable relative age string for a given past timestamp.
---
--- @param ts integer  # Unix timestamp (seconds)
--- @return string
local function relative_age(ts)
	local now = os.time()
	local diff = now - ts

	if diff < 0 then
		return "in the future"
	elseif diff < 60 then
		return "just now"
	elseif diff < 3600 then
		local mins = math.floor(diff / 60)
		return string.format("%d min%s ago", mins, mins == 1 and "" or "s")
	elseif diff < 86400 then
		local hrs = math.floor(diff / 3600)
		return string.format("%d hr%s ago", hrs, hrs == 1 and "" or "s")
	elseif diff < 86400 * 30 then
		local days = math.floor(diff / 86400)
		return string.format("%d day%s ago", days, days == 1 and "" or "s")
	elseif diff < 86400 * 365 then
		local months = math.floor(diff / (86400 * 30))
		return string.format("%d month%s ago", months, months == 1 and "" or "s")
	else
		local years = math.floor(diff / (86400 * 365))
		return string.format("%d year%s ago", years, years == 1 and "" or "s")
	end
end

--- @param buf integer
--- @param ns  integer
function M.render(buf, ns)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	if lines[1] ~= "---" then
		return
	end

	for lnum = 2, #lines do
		local line = lines[lnum]

		if line == "---" then
			break
		end

		-- Match `date: YYYY-MM-DD` or `date: YYYY-MM-DD ...`
		local date_str = line:match("^date:%s*(%d%d%d%d%-%d%d%-%d%d)")
		if date_str then
			local ts = parse_date(date_str)
			if ts then
				local age = relative_age(ts)
				local row = lnum - 1
				vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
					virt_text = { { "· " .. age, "BookwyrmTimestamp" } },
					virt_text_pos = "eol",
				})
			end
		end
	end
end

return M

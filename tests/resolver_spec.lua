--- Tests for lua/bookwyrm/api/resolver.lua
---
--- Run from repo root with plain Lua (no Neovim, no SQLite required):
---   lua tests/resolver_spec.lua
---
--- Or from within Neovim (with the plugin directory on runtimepath):
---   :luafile tests/resolver_spec.lua

local t = require("tests.test_runner")
local resolver = require("bookwyrm.api.resolver")

-- ---------------------------------------------------------------------------
-- Helpers: mock sqlite-like connection
-- ---------------------------------------------------------------------------

--- Build a mock sqlite connection whose `eval` method returns predetermined
--- rows based on the SQL statement that is passed to it.
---
--- `alias_rows`  — rows returned when the query mentions the aliases table
--- `note_rows`   — rows returned when the query mentions the notes table
---
--- @param alias_rows table[]
--- @param note_rows  table[]
--- @return table   # a conn mock compatible with resolve_with_conn
local function mock_conn(alias_rows, note_rows)
	return {
		eval = function(_, sql, _)
			if sql:find("aliases") then
				return alias_rows
			end
			return note_rows
		end,
	}
end

-- ---------------------------------------------------------------------------
-- link_at: extract [[...]] at a column position
-- ---------------------------------------------------------------------------

do
	local text = "[[MyNote]]"
	t.eq("MyNote", resolver.link_at(text, 1), "link_at: start of brackets")
	t.eq("MyNote", resolver.link_at(text, 5), "link_at: middle of content")
	t.eq("MyNote", resolver.link_at(text, 9), "link_at: last content char")
end

do
	local text = "See [[NoteA]] and [[NoteB]]."
	t.eq("NoteA", resolver.link_at(text, 5), "link_at: first link start bracket")
	t.eq("NoteA", resolver.link_at(text, 8), "link_at: inside first link")
	t.eq("NoteB", resolver.link_at(text, 20), "link_at: inside second link")
end

do
	local text = "No links here."
	t.eq(nil, resolver.link_at(text, 1), "link_at: no links → nil")
	t.eq(nil, resolver.link_at(text, 7), "link_at: no links mid-line → nil")
end

do
	-- Cursor sitting after the closing ]] should not match
	local text = "[[Note]] rest"
	t.eq(nil, resolver.link_at(text, 9), "link_at: past closing bracket → nil")
end

-- ---------------------------------------------------------------------------
-- resolve_with_conn: alias lookup (case-insensitive)
-- ---------------------------------------------------------------------------

do
	-- Alias match: exact case
	local conn = mock_conn({ { relative_path = "notes/my-note.md" } }, {})
	local result = resolver.resolve_with_conn("my-note", conn, 1, "/nb")
	t.eq("/nb/notes/my-note.md", result, "resolve: alias exact case")
end

do
	-- Alias match: different case in link text
	local conn = mock_conn({ { relative_path = "notes/My Note.md" } }, {})
	local result = resolver.resolve_with_conn("MY NOTE", conn, 1, "/nb")
	t.eq("/nb/notes/My Note.md", result, "resolve: alias case-insensitive")
end

do
	-- Alias match takes priority over title match
	local alias_conn = mock_conn(
		{ { relative_path = "by-alias.md" } },
		{ { relative_path = "by-title.md" } }
	)
	local result = resolver.resolve_with_conn("note", alias_conn, 1, "/nb")
	t.eq("/nb/by-alias.md", result, "resolve: alias takes priority over title")
end

-- ---------------------------------------------------------------------------
-- resolve_with_conn: title lookup (case-insensitive)
-- ---------------------------------------------------------------------------

do
	-- No alias, but note title matches
	local conn = mock_conn({}, { { relative_path = "notes/meeting.md" } })
	local result = resolver.resolve_with_conn("Meeting", conn, 1, "/nb")
	t.eq("/nb/notes/meeting.md", result, "resolve: title match")
end

do
	-- Case-insensitive title match
	local conn = mock_conn({}, { { relative_path = "notes/meeting.md" } })
	local result = resolver.resolve_with_conn("MEETING", conn, 1, "/nb")
	t.eq("/nb/notes/meeting.md", result, "resolve: title case-insensitive")
end

-- ---------------------------------------------------------------------------
-- resolve_with_conn: no match
-- ---------------------------------------------------------------------------

do
	local conn = mock_conn({}, {})
	local result = resolver.resolve_with_conn("nonexistent", conn, 1, "/nb")
	t.eq(nil, result, "resolve: no match returns nil")
end

-- ---------------------------------------------------------------------------
-- resolve_with_conn: edge cases
-- ---------------------------------------------------------------------------

do
	-- Empty link text
	local conn = mock_conn({ { relative_path = "x.md" } }, {})
	t.eq(nil, resolver.resolve_with_conn("", conn, 1, "/nb"), "resolve: empty string returns nil")
	t.eq(nil, resolver.resolve_with_conn(nil, conn, 1, "/nb"), "resolve: nil returns nil")
end

do
	-- Missing conn/nb_id/root_path
	local conn = mock_conn({}, {})
	t.eq(nil, resolver.resolve_with_conn("note", nil, 1, "/nb"), "resolve: nil conn returns nil")
	t.eq(nil, resolver.resolve_with_conn("note", conn, nil, "/nb"), "resolve: nil nb_id returns nil")
	t.eq(nil, resolver.resolve_with_conn("note", conn, 1, nil), "resolve: nil root_path returns nil")
end

do
	-- Link text with anchor fragment: only the part before # is matched
	local conn = mock_conn({}, { { relative_path = "notes/foo.md" } })
	local result = resolver.resolve_with_conn("Foo#section-1", conn, 1, "/nb")
	t.eq("/nb/notes/foo.md", result, "resolve: strips anchor fragment before lookup")
end

do
	-- Link text with display alias pipe: only the part before | is matched
	local conn = mock_conn({}, { { relative_path = "notes/bar.md" } })
	local result = resolver.resolve_with_conn("Bar|Display Text", conn, 1, "/nb")
	t.eq("/nb/notes/bar.md", result, "resolve: strips display alias before lookup")
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

t.summary()

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
-- Helpers: mock BookwyrmDB
-- ---------------------------------------------------------------------------

--- Build a mock BookwyrmDB that records the arguments passed to each lookup
--- and returns the supplied note objects.
---
--- `alias_note`  — BookwyrmNote-like table returned by resolve_by_alias, or nil
--- `title_note`  — BookwyrmNote-like table returned by resolve_by_title, or nil
---
--- The returned `db` table exposes a `.calls` subtable:
---   db.calls.alias  — { nb_id, alias }  set when resolve_by_alias is called
---   db.calls.title  — { nb_id, title }  set when resolve_by_title is called
---
--- @param alias_note table?
--- @param title_note  table?
--- @return table   # a db mock compatible with resolve_with_conn
local function mock_db(alias_note, title_note)
	local calls = {}
	local db = {
		calls = calls,
		notes = {
			resolve_by_alias = function(_, nb_id, alias)
				calls.alias = { nb_id = nb_id, alias = alias }
				return alias_note
			end,
			resolve_by_title = function(_, nb_id, title)
				calls.title = { nb_id = nb_id, title = title }
				return title_note
			end,
		},
	}
	return db
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
	local db = mock_db({ relative_path = "notes/my-note.md" }, nil)
	local result = resolver.resolve_with_conn("my-note", db, 1, "/nb")
	t.eq("/nb/notes/my-note.md", result, "resolve: alias exact case")
	t.eq("my-note", db.calls.alias.alias, "resolve: alias exact case — correct alias passed to lookup")
end

do
	-- Alias match: different case in link text — resolver must lowercase before lookup
	local db = mock_db({ relative_path = "notes/My Note.md" }, nil)
	local result = resolver.resolve_with_conn("MY NOTE", db, 1, "/nb")
	t.eq("/nb/notes/My Note.md", result, "resolve: alias case-insensitive")
	t.eq("my note", db.calls.alias.alias, "resolve: alias case-insensitive — lowercased before lookup")
end

do
	-- Alias match takes priority over title match
	local db = mock_db({ relative_path = "by-alias.md" }, { relative_path = "by-title.md" })
	local result = resolver.resolve_with_conn("note", db, 1, "/nb")
	t.eq("/nb/by-alias.md", result, "resolve: alias takes priority over title")
end

-- ---------------------------------------------------------------------------
-- resolve_with_conn: title lookup (case-insensitive)
-- ---------------------------------------------------------------------------

do
	-- No alias, but note title matches
	local db = mock_db(nil, { relative_path = "notes/meeting.md" })
	local result = resolver.resolve_with_conn("Meeting", db, 1, "/nb")
	t.eq("/nb/notes/meeting.md", result, "resolve: title match")
	t.eq("meeting", db.calls.title.title, "resolve: title match — lowercased before lookup")
end

do
	-- Case-insensitive title match — resolver must lowercase before lookup
	local db = mock_db(nil, { relative_path = "notes/meeting.md" })
	local result = resolver.resolve_with_conn("MEETING", db, 1, "/nb")
	t.eq("/nb/notes/meeting.md", result, "resolve: title case-insensitive")
	t.eq("meeting", db.calls.title.title, "resolve: title case-insensitive — lowercased before lookup")
end

-- ---------------------------------------------------------------------------
-- resolve_with_conn: no match
-- ---------------------------------------------------------------------------

do
	local db = mock_db(nil, nil)
	local result = resolver.resolve_with_conn("nonexistent", db, 1, "/nb")
	t.eq(nil, result, "resolve: no match returns nil")
end

-- ---------------------------------------------------------------------------
-- resolve_with_conn: edge cases
-- ---------------------------------------------------------------------------

do
	-- Empty link text
	local db = mock_db({ relative_path = "x.md" }, nil)
	t.eq(nil, resolver.resolve_with_conn("", db, 1, "/nb"), "resolve: empty string returns nil")
	t.eq(nil, resolver.resolve_with_conn(nil, db, 1, "/nb"), "resolve: nil returns nil")
end

do
	-- Missing db/nb_id/root_path
	local db = mock_db(nil, nil)
	t.eq(nil, resolver.resolve_with_conn("note", nil, 1, "/nb"), "resolve: nil db returns nil")
	t.eq(nil, resolver.resolve_with_conn("note", db, nil, "/nb"), "resolve: nil nb_id returns nil")
	t.eq(nil, resolver.resolve_with_conn("note", db, 1, nil), "resolve: nil root_path returns nil")
end

do
	-- Link text with anchor fragment: only the part before # is looked up
	local db = mock_db(nil, { relative_path = "notes/foo.md" })
	local result = resolver.resolve_with_conn("Foo#section-1", db, 1, "/nb")
	t.eq("/nb/notes/foo.md", result, "resolve: strips anchor fragment before lookup")
	t.eq("foo", db.calls.title.title, "resolve: strips anchor fragment — only title part passed to lookup")
end

do
	-- Link text with display alias pipe: only the part before | is looked up
	local db = mock_db(nil, { relative_path = "notes/bar.md" })
	local result = resolver.resolve_with_conn("Bar|Display Text", db, 1, "/nb")
	t.eq("/nb/notes/bar.md", result, "resolve: strips display alias before lookup")
	t.eq("bar", db.calls.title.title, "resolve: strips display alias — only note name passed to lookup")
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

if arg and arg[0]:find(debug.getinfo(1).source:sub(2)) then
	t.summary()
end

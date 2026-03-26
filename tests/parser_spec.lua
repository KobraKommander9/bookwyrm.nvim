--- Tests for lua/bookwyrm/parser.lua
---
--- Run from repo root with plain Lua:
---   lua tests/parser_spec.lua
---
--- Or from Neovim (with the plugin directory on runtimepath):
---   :luafile tests/parser_spec.lua

-- Allow running from the repo root without installing the plugin
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local t = require("tests.test_runner")
local parser = require("bookwyrm.parser")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function parse(lines)
	return parser.parse(lines)
end

-- ---------------------------------------------------------------------------
-- Links
-- ---------------------------------------------------------------------------

do
	local result = parse({ "[[MyNote]]" })
	t.eq(1, #result.links, "simple link count")
	t.eq("MyNote", result.links[1].target_note, "simple link target")
	t.eq(nil, result.links[1].alias, "simple link has no alias")
	t.eq(nil, result.links[1].target_anchor, "simple link has no anchor")
end

do
	local result = parse({ "[[MyNote|My Alias]]" })
	t.eq(1, #result.links, "aliased link count")
	t.eq("MyNote", result.links[1].target_note, "aliased link target")
	t.eq("My Alias", result.links[1].alias, "aliased link alias")
end

do
	local result = parse({ "[[MyNote#section-1]]" })
	t.eq(1, #result.links, "link with anchor count")
	t.eq("MyNote", result.links[1].target_note, "link with anchor target")
	t.eq("section-1", result.links[1].target_anchor, "link with anchor id")
end

do
	local result = parse({ "[[MyNote#section-1|Display]]" })
	t.eq(1, #result.links, "link with anchor and alias count")
	t.eq("MyNote", result.links[1].target_note, "link anchor+alias target")
	t.eq("section-1", result.links[1].target_anchor, "link anchor+alias anchor")
	t.eq("Display", result.links[1].alias, "link anchor+alias alias")
end

do
	local result = parse({ "See [[NoteA]] and [[NoteB]]." })
	t.eq(2, #result.links, "two links on same line")
	t.eq("NoteA", result.links[1].target_note, "first link target")
	t.eq("NoteB", result.links[2].target_note, "second link target")
end

do
	local result = parse({ "No links here." })
	t.eq(0, #result.links, "no links")
end

-- ---------------------------------------------------------------------------
-- Tags (inline)
-- ---------------------------------------------------------------------------

do
	local result = parse({ "Hello #world and #lua." })
	t.eq(2, #result.tags, "inline tags count")
	t.eq("world", result.tags[1].tag, "first inline tag")
	t.eq("lua", result.tags[2].tag, "second inline tag")
end

do
	-- Tags inside a link should be masked out and not double-counted
	local result = parse({ "[[Note]] #outside" })
	t.eq(1, #result.tags, "tags outside link only")
	t.eq("outside", result.tags[1].tag, "tag outside link value")
end

do
	-- Deduplication: same tag twice in the file
	local result = parse({ "#foo", "#foo" })
	t.eq(1, #result.tags, "deduplicated tags")
end

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------

do
	local result = parse({ "- [ ] Buy milk" })
	t.eq(1, #result.tasks, "incomplete task count")
	t.eq("Buy milk", result.tasks[1].content, "incomplete task content")
	t.eq(0, result.tasks[1].status, "incomplete task status")
end

do
	local result = parse({ "- [x] Done thing" })
	t.eq(1, #result.tasks, "complete task count")
	t.eq("Done thing", result.tasks[1].content, "complete task content")
	t.eq(1, result.tasks[1].status, "complete task status")
end

do
	local result = parse({ "- [X] Done thing" })
	t.eq(1, result.tasks[1].status, "uppercase X complete task status")
end

do
	local result = parse({ "- [ ] Fix #bug in #parser" })
	t.eq(1, #result.tasks, "task with tags count")
	t.eq(2, #result.tasks[1].tags, "task tags count")
	t.eq("bug", result.tasks[1].tags[1], "task first tag")
	t.eq("parser", result.tasks[1].tags[2], "task second tag")
end

do
	local result = parse({ "- [ ] Task one", "- [x] Task two" })
	t.eq(2, #result.tasks, "two tasks count")
	t.eq(0, result.tasks[1].line, "first task line number")
	t.eq(1, result.tasks[2].line, "second task line number")
end

do
	local result = parse({ "Not a task" })
	t.eq(0, #result.tasks, "no tasks")
end

-- ---------------------------------------------------------------------------
-- Aliases
-- ---------------------------------------------------------------------------

do
	local result = parse({ "---", "aliases: [foo, bar]", "---", "content" })
	t.eq(2, #result.aliases, "YAML aliases count")
	t.eq("foo", result.aliases[1].alias, "YAML alias 1")
	t.eq("bar", result.aliases[2].alias, "YAML alias 2")
end

do
	local result = parse({ "---", "alias: [single]", "---" })
	t.eq(1, #result.aliases, "YAML alias singular count")
	t.eq("single", result.aliases[1].alias, "YAML alias singular value")
end

do
	local result = parse({ "---", 'alias: ["quoted"]', "---" })
	t.eq(1, #result.aliases, "YAML alias singular quoted count")
	t.eq("quoted", result.aliases[1].alias, "YAML alias singular quoted value")
end

do
	local result = parse({ "alias:: My Alias" })
	t.eq(1, #result.aliases, "inline alias count")
	t.eq("My Alias", result.aliases[1].alias, "inline alias value")
end

do
	-- Deduplication
	local result = parse({
		"---",
		"aliases: [dup]",
		"---",
		"alias:: dup",
	})
	t.eq(1, #result.aliases, "deduplicated aliases")
end

-- ---------------------------------------------------------------------------
-- YAML front-matter tags
-- ---------------------------------------------------------------------------

do
	local result = parse({ "---", "tags: [lua, neovim]", "---" })
	t.eq(2, #result.tags, "YAML tags count")
	t.eq("lua", result.tags[1].tag, "YAML tag 1")
	t.eq("neovim", result.tags[2].tag, "YAML tag 2")
end

do
	-- Front-matter tags and inline tags are merged and deduplicated
	local result = parse({ "---", "tags: [lua]", "---", "#lua #extra" })
	t.eq(2, #result.tags, "merged+deduped tags count")
end

-- ---------------------------------------------------------------------------
-- Anchors – span
-- ---------------------------------------------------------------------------

do
	local result = parse({ "[important text]^my-anchor" })
	t.eq(1, #result.anchors, "span anchor count")
	local a = result.anchors[1]
	t.eq("span", a.type, "span anchor type")
	t.eq("my-anchor", a.anchor_id, "span anchor id")
	t.eq("important text", a.content, "span anchor content")
end

do
	local result = parse({ "prefix [content]^anchor-1 suffix" })
	t.eq(1, #result.anchors, "span anchor in middle of line")
	t.eq("anchor-1", result.anchors[1].anchor_id, "span anchor in middle id")
end

-- ---------------------------------------------------------------------------
-- Anchors – block
-- ---------------------------------------------------------------------------

do
	local result = parse({ "Some paragraph text ^block-id" })
	t.eq(1, #result.anchors, "block anchor count")
	local a = result.anchors[1]
	t.eq("block", a.type, "block anchor type")
	t.eq("block-id", a.anchor_id, "block anchor id")
end

do
	-- Block anchor at the very start of the line (no prefix)
	local result = parse({ "^standalone" })
	t.eq(1, #result.anchors, "standalone block anchor count")
	t.eq("block", result.anchors[1].type, "standalone block anchor type")
	t.eq("standalone", result.anchors[1].anchor_id, "standalone block anchor id")
end

do
	-- Block anchor should scan back through the paragraph
	local result = parse({
		"Line one of para.",
		"Line two of para ^para-id",
	})
	t.eq(1, #result.anchors, "multi-line block anchor count")
	local a = result.anchors[1]
	t.eq("block", a.type, "multi-line block anchor type")
	t.eq("para-id", a.anchor_id, "multi-line block anchor id")
	-- para_start_row should be 0 (Line one)
	t.eq(0, a.loc.start.line, "multi-line block anchor start line")
end

do
	-- Blank line should stop backward scan
	local result = parse({
		"Previous paragraph.",
		"",
		"Current paragraph ^here",
	})
	t.eq(1, #result.anchors, "block anchor stops at blank line")
	local a = result.anchors[1]
	-- para_start_row should be 2 (0-indexed), not 0
	t.eq(2, a.loc.start.line, "block anchor start after blank line")
end

-- ---------------------------------------------------------------------------
-- Anchors – range
-- ---------------------------------------------------------------------------

do
	local result = parse({ "[^start:r1]some content[^end:r1]" })
	t.eq(1, #result.anchors, "inline range anchor count")
	local a = result.anchors[1]
	t.eq("range", a.type, "inline range anchor type")
	t.eq("r1", a.anchor_id, "inline range anchor id")
	t.eq("some content", a.content, "inline range anchor content")
end

do
	local result = parse({
		"[^start:r2]begin here",
		"middle line",
		"end here[^end:r2]",
	})
	t.eq(1, #result.anchors, "multi-line range anchor count")
	local a = result.anchors[1]
	t.eq("range", a.type, "multi-line range anchor type")
	t.eq("r2", a.anchor_id, "multi-line range anchor id")
	-- Content should span across lines
	t.ok(a.content:find("begin here"), "range content has begin")
	t.ok(a.content:find("middle line"), "range content has middle")
	t.ok(a.content:find("end here"), "range content has end")
end

-- ---------------------------------------------------------------------------
-- Mixed content
-- ---------------------------------------------------------------------------

do
	local result = parse({
		"---",
		"aliases: [myalias]",
		"tags: [meta]",
		"---",
		"",
		"See [[OtherNote|Link]] for details.",
		"",
		"- [ ] Fix #bug",
		"- [x] Done #feature",
		"",
		"[span content]^span-1",
		"",
		"Paragraph text ^blk",
	})

	t.eq(1, #result.links, "mixed: link count")
	t.eq("OtherNote", result.links[1].target_note, "mixed: link target")
	t.eq("Link", result.links[1].alias, "mixed: link alias")

	t.eq(2, #result.tasks, "mixed: task count")
	t.eq(0, result.tasks[1].status, "mixed: task 1 status")
	t.eq(1, result.tasks[2].status, "mixed: task 2 status")

	-- tags: "meta" from YAML + "bug" and "feature" from task lines (inline)
	local tag_names = {}
	for _, tg in ipairs(result.tags) do
		tag_names[tg.tag] = true
	end
	t.ok(tag_names["meta"], "mixed: meta tag from YAML")
	t.ok(tag_names["bug"], "mixed: bug tag from task")
	t.ok(tag_names["feature"], "mixed: feature tag from task")

	t.eq(1, #result.aliases, "mixed: alias count")
	t.eq("myalias", result.aliases[1].alias, "mixed: alias value")

	local anchor_types = {}
	for _, a in ipairs(result.anchors) do
		anchor_types[a.type] = (anchor_types[a.type] or 0) + 1
	end
	t.eq(1, anchor_types["span"], "mixed: span anchor count")
	t.eq(1, anchor_types["block"], "mixed: block anchor count")
end

-- ---------------------------------------------------------------------------
-- Edge cases
-- ---------------------------------------------------------------------------

do
	local result = parse({})
	t.eq(0, #result.links, "empty input: no links")
	t.eq(0, #result.tags, "empty input: no tags")
	t.eq(0, #result.tasks, "empty input: no tasks")
	t.eq(0, #result.aliases, "empty input: no aliases")
	t.eq(0, #result.anchors, "empty input: no anchors")
end

do
	local result = parse({ "Plain text, no markup at all." })
	t.eq(0, #result.links, "plain text: no links")
	t.eq(0, #result.tags, "plain text: no tags")
end

do
	-- ^ inside a word should not produce a block anchor
	local result = parse({ "2^10 = 1024" })
	t.eq(0, #result.anchors, "caret in exponent is not a block anchor")
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

t.summary()

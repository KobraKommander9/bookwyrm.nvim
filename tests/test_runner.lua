--- Minimal test runner for pure-Lua modules.
---
--- Usage (from repo root):
---   lua tests/test_runner.lua
---
--- Or from within Neovim:
---   :luafile tests/test_runner.lua

local runner = {}

if not package.path:find("./lua/?.lua") then
	package.path = "./?.lua;./lua/?.lua;./lua/?/init.lua;" .. package.path
end

runner.passed = 0
runner.failed = 0
runner.errors = {}

--- Deep-equality check for tables (and primitives).
local function deep_eq(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deep_eq(v, b[k]) then
			return false
		end
	end
	for k, v in pairs(b) do
		if not deep_eq(v, a[k]) then
			return false
		end
	end
	return true
end

--- Serialises a value for error messages.
local function repr(v, depth)
	depth = depth or 0
	if type(v) == "table" then
		if depth > 3 then
			return "{...}"
		end
		local parts = {}
		for k, val in pairs(v) do
			local key = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
			table.insert(parts, key .. " = " .. repr(val, depth + 1))
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return tostring(v)
end

--- Assert two values are deeply equal.
function runner.eq(expected, actual, label)
	if deep_eq(expected, actual) then
		runner.passed = runner.passed + 1
	else
		runner.failed = runner.failed + 1
		local msg =
			string.format("FAIL [%s]\n  expected: %s\n  actual:   %s", label or "?", repr(expected), repr(actual))
		table.insert(runner.errors, msg)
		print(msg)
	end
end

--- Assert a value is truthy.
function runner.ok(val, label)
	if val then
		runner.passed = runner.passed + 1
	else
		runner.failed = runner.failed + 1
		local msg = string.format("FAIL [%s]  expected truthy, got %s", label or "?", repr(val))
		table.insert(runner.errors, msg)
		print(msg)
	end
end

--- Print final summary.
function runner.summary()
	print(string.format("\n%d passed, %d failed", runner.passed, runner.failed))
	if runner.failed > 0 and not vim then
		os.exit(1)
	end
end

return runner

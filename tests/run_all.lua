package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local runner = require("tests.test_runner")

print("--- Initializing Dynamic Test Discovery ---")

local handle = io.popen("ls tests/*_spec.lua")
if not handle then
	print("Error: Could not list tests directory.")
	os.exit(1)
end

local files = handle:read("*a")
handle:close()

for file_path in files:gmatch("[^\r\n]+") do
	local module_name = file_path:gsub("%.lua$", ""):gsub("/", ".")

	print("\n--- Executing: " .. module_name .. " ---")

	local success, err = pcall(function()
		require(module_name)
	end)

	if not success then
		runner.failed = runner.failed + 1
		print("ERROR in " .. module_name .. ": " .. tostring(err))
	end
end

runner.summary()

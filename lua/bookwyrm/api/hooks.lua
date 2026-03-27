--- @class BookwyrmHooksAPI
local M = {}

--- @alias BookwyrmEvent "pre_sync"|"post_sync"|"note_opened"|"note_captured"

--- Registry mapping event names to lists of callbacks.
--- @type table<string, function[]>
local registry = {}

--- Registers a callback for a named lifecycle event.
---
--- @param event BookwyrmEvent # The name of the event
--- @param callback function # The Lua function to invoke when the event fires
function M.register(event, callback)
	if not registry[event] then
		registry[event] = {}
	end
	table.insert(registry[event], callback)
end

--- Fires all callbacks registered for a named lifecycle event.
---
--- @param event BookwyrmEvent # The name of the event
--- @param payload any? # Optional data passed to each callback
function M.fire(event, payload)
	local callbacks = registry[event]
	if not callbacks then
		return
	end
	for _, cb in ipairs(callbacks) do
		cb(payload)
	end
end

return M

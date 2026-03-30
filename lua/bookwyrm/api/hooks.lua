--- @class BookwyrmHooksAPI
local M = {}

--- @alias BookwyrmEvent "pre_sync"|"post_sync"|"note_opened"|"note_captured"

--- Registry mapping event names to lists of callbacks.
--- @type table<string, function[]>
local registry = {}

--- Maps internal event names to Neovim User autocommand patterns.
--- @type table<string, string>
local nvim_patterns = {
	pre_sync = "BookwyrmPreSync",
	post_sync = "BookwyrmPostSync",
	note_opened = "BookwyrmNoteOpened",
	note_captured = "BookwyrmNoteCaptured",
}

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

--- Fires all callbacks registered for a named lifecycle event and emits the
--- corresponding Neovim `User` autocommand so users can hook in via
--- `vim.api.nvim_create_autocmd("User", { pattern = "BookwyrmXxx", ... })`.
---
--- @param event BookwyrmEvent # The name of the event
--- @param payload any? # Optional data passed to each callback and as `data` to the autocmd
function M.fire(event, payload)
	local callbacks = registry[event]
	if callbacks then
		for _, cb in ipairs(callbacks) do
			cb(payload)
		end
	end

	local pattern = nvim_patterns[event]
	if pattern then
		vim.api.nvim_exec_autocmds("User", { pattern = pattern, data = payload })
	end
end

return M

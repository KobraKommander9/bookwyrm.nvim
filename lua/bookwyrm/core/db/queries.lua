local M = {}

--- @param db sqlite_db
--- @param table_name string
--- @param items table[]
--- @param mapper function
function M.batch_insert(db, table_name, items, mapper)
	if #items == 0 then
		return
	end

	local data = {}
	for _, item in ipairs(items) do
		table.insert(data, mapper(item))
	end

	if not db:insert(table_name, data) then
		error("batch insert failed for " .. table_name)
	end
end

return M

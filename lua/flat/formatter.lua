local M = {}

--- Formats flat line array
--- @param lines string[]
--- @return string[]
function M.format_lines(lines)
	local new_lines = {}
	for _, line in ipairs(lines) do
		local formatted = line:gsub("%s+$", "")
		formatted = formatted:gsub("^(#!sec:)%s+(.*)$", "%1%2")
		formatted = formatted:gsub("^(#!const:)%s*(.-)%s*:%s*(.*)$", "%1%2:%3")
		formatted = formatted:gsub("^(#!enum:)%s+(.*)$", "%1%2")
		table.insert(new_lines, formatted)
	end
	return new_lines
end

--- Conform.nvim formatter entrypoint
--- @param _ table
--- @param _ table
--- @param lines string[]
--- @param callback function
function M.format(_, _, lines, callback)
	callback(nil, M.format_lines(lines))
end

return M

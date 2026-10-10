-- lua/flat/parser.lua
local M = {}

local function read_file_lines(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil
	end
	local lines = {}
	for line in file:lines() do
		table.insert(lines, line)
	end
	file:close()
	return lines
end

-- パス1: シンボルの登録（インポート再帰解決対応）
function M.parse_pass1(bufnr, lines, current_file_path, visited)
	visited = visited or {}
	current_file_path = current_file_path or vim.api.nvim_buf_get_name(bufnr)

	local abs_path = vim.fn.fnamemodify(current_file_path, ":p")
	if visited[abs_path] then
		return {}
	end
	visited[abs_path] = true

	local symbols = {}
	local current_dir = vim.fn.fnamemodify(abs_path, ":h")

	for i, line in ipairs(lines) do
		local import_path = line:match("^#!import:%s*(.-)%s*$")
		if import_path then
			local target_path = vim.fn.resolve(current_dir .. "/" .. import_path)
			local imported_lines = read_file_lines(target_path)
			if imported_lines then
				local sub_symbols = M.parse_pass1(nil, imported_lines, target_path, visited)
				for _, sym in ipairs(sub_symbols) do
					table.insert(symbols, sym)
				end
			end
		end

		local kind, name = line:match("^#!(%w+):%s*(.-)%s*$")
		if kind and (kind == "section" or kind == "block") then
			name = name:gsub("%s*|.*$", "")

			if #symbols > 0 and symbols[#symbols].file == current_file_path then
				symbols[#symbols].end_line = i - 1
			end

			table.insert(symbols, {
				kind = kind,
				name = name,
				start_line = i,
				end_line = #lines,
				file = current_file_path,
			})
		end
	end

	return symbols
end

return M

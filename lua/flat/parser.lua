-- lua/flat/parser.lua
local M = {}

local function read_file_lines(filepath)
	if vim.fn.filereadable(filepath) ~= 1 then
		return nil
	end
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

local function get_all_symbols_from_file(filepath, visited)
	local abs_path = vim.fn.fnamemodify(filepath, ":p")
	if visited[abs_path] then
		return {}
	end
	visited[abs_path] = true

	local lines = read_file_lines(abs_path)
	if not lines then
		return {}
	end

	local symbols = {}
	local current_dir = vim.fn.fnamemodify(abs_path, ":h")
	local i = 1
	while i <= #lines do
		local line = lines[i]

		-- 1. 新インポート構文: #!import: { ... } の次に |from(path) が来る形式
		local import_symbols_str = line:match("^#!import:%s*{%s*(.-)%s*}%s*$")
		if import_symbols_str and i < #lines then
			local next_line = lines[i + 1]
			local import_path = next_line:match("^%s*|%s*from%((.-)%s*%)%s*$")
			if import_path then
				i = i + 1 -- 次の行も消費
				local target_path = vim.fn.fnamemodify(current_dir .. "/" .. import_path, ":p")
				local sub_symbols = get_all_symbols_from_file(target_path, visited)
				local allowed = {}
				for s in import_symbols_str:gmatch("[^,%s]+") do
					allowed[s] = true
				end
				for _, sym in ipairs(sub_symbols) do
					if allowed[sym.name] then
						table.insert(symbols, sym)
					end
				end
			end
		end

		-- 2. 従来型・1行型インポートの互換性維持
		local inline_symbols, inline_path = line:match("^#!import:%s*{%s*(.-)%s*}%s+from%s+(.-)%s*$")
		local simple_import_path = not inline_path and line:match("^#!import:%s*(.-)%s*$") or nil

		if inline_path then
			inline_path = vim.trim(inline_path)
			local target_path = vim.fn.fnamemodify(current_dir .. "/" .. inline_path, ":p")
			local sub_symbols = get_all_symbols_from_file(target_path, visited)
			local allowed = {}
			for s in inline_symbols:gmatch("[^,%s]+") do
				allowed[s] = true
			end
			for _, sym in ipairs(sub_symbols) do
				if allowed[sym.name] then
					table.insert(symbols, sym)
				end
			end
		elseif simple_import_path and not vim.startswith(simple_import_path, "{") then
			simple_import_path = vim.trim(simple_import_path)
			local target_path = vim.fn.fnamemodify(current_dir .. "/" .. simple_import_path, ":p")
			local sub_symbols = get_all_symbols_from_file(target_path, visited)
			for _, sym in ipairs(sub_symbols) do
				table.insert(symbols, sym)
			end
		end

		local kind, name = line:match("^#!(%w+):%s*(.-)%s*$")
		if kind and (kind == "section" or kind == "block") then
			name = name:gsub("%s*|.*$", "")
			table.insert(symbols, {
				kind = kind,
				name = name,
				start_line = i,
				end_line = #lines,
				file = abs_path,
			})
		end
		i = i + 1
	end

	for idx = 1, #symbols do
		if symbols[idx].file == abs_path then
			for j = idx + 1, #symbols do
				if symbols[j].file == abs_path then
					symbols[idx].end_line = symbols[j].start_line - 1
					break
				end
			end
		end
	end

	return symbols
end

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
	local i = 1

	while i <= #lines do
		local line = lines[i]

		-- 新インポート構文のパース
		local import_symbols_str = line:match("^#!import:%s*{%s*(.-)%s*}%s*$")
		if import_symbols_str and i < #lines then
			local next_line = lines[i + 1]
			local import_path = next_line:match("^%s*|%s*from%((.-)%s*%)%s*$")
			if import_path then
				i = i + 1
				import_path = vim.trim(import_path)
				local target_path = vim.fn.fnamemodify(current_dir .. "/" .. import_path, ":p")
				local sub_symbols = get_all_symbols_from_file(target_path, {})
				local allowed = {}
				for s in import_symbols_str:gmatch("[^,%s]+") do
					allowed[s] = true
				end
				for _, sym in ipairs(sub_symbols) do
					if allowed[sym.name] then
						table.insert(symbols, sym)
					end
				end
			end
		end

		-- 従来型・1行型のフォールバック
		local inline_symbols, inline_path = line:match("^#!import:%s*{%s*(.-)%s*}%s+from%s+(.-)%s*$")
		local simple_import_path = not inline_path and line:match("^#!import:%s*(.-)%s*$") or nil

		if inline_path then
			inline_path = vim.trim(inline_path)
			local target_path = vim.fn.fnamemodify(current_dir .. "/" .. inline_path, ":p")
			local sub_symbols = get_all_symbols_from_file(target_path, {})
			local allowed = {}
			for s in inline_symbols:gmatch("[^,%s]+") do
				allowed[s] = true
			end
			for _, sym in ipairs(sub_symbols) do
				if allowed[sym.name] then
					table.insert(symbols, sym)
				end
			end
		elseif simple_import_path and not vim.startswith(simple_import_path, "{") then
			simple_import_path = vim.trim(simple_import_path)
			local target_path = vim.fn.fnamemodify(current_dir .. "/" .. simple_import_path, ":p")
			local sub_symbols = get_all_symbols_from_file(target_path, {})
			for _, sym in ipairs(sub_symbols) do
				table.insert(symbols, sym)
			end
		end

		local kind, name = line:match("^#!(%w+):%s*(.-)%s*$")
		if kind and (kind == "section" or kind == "block") then
			name = name:gsub("%s*|.*$", "")
			if #symbols > 0 and symbols[#symbols].file == abs_path then
				symbols[#symbols].end_line = i - 1
			end
			table.insert(symbols, {
				kind = kind,
				name = name,
				start_line = i,
				end_line = #lines,
				file = abs_path,
			})
		end
		i = i + 1
	end

	return symbols
end

return M

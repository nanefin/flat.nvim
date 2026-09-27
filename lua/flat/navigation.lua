local M = {}
local parser = require("flat.parser")

local function trim(s)
	return s and (s:match("^%s*(.-)%s*$") or s) or ""
end

-- Resolve identifier and category under cursor
local function get_identifier_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1

	-- 1. Declaration directive check (#!sec:Name, #!const:Name, #!enum:Name)
	if line:sub(1, 6) == "#!sec:" then
		return trim(line:sub(7)), "sec"
	elseif line:sub(1, 8) == "#!const:" then
		local body = line:sub(9)
		local name = body:match("^([%w_]+)")
		return name, "const"
	elseif line:sub(1, 7) == "#!enum:" then
		local body = line:sub(8)
		local name = body:match("^([%w_]+)")
		return name, "enum"
	end

	-- 2. Inline reference check (#$Ref; or #$Enum:Value;)
	local search_pos = 1
	while search_pos <= #line do
		local s_idx = line:find("#%$", search_pos)
		if not s_idx then
			break
		end

		local semi_idx = line:find(";", s_idx)
		if semi_idx and col >= s_idx and col <= semi_idx then
			local raw = line:sub(s_idx + 2, semi_idx - 1)
			if raw:find(":") then
				local enum_name = raw:match("^([%w_]+):")
				return enum_name, "enum"
			else
				return trim(raw), "ref"
			end
		end
		search_pos = s_idx + 2
	end

	-- 3. Fallback to standard word under cursor
	return vim.fn.expand("<cword>"), "general"
end

--- 1. gd: Goto Definition
function M.goto_definition()
	local target_name, _ = get_identifier_under_cursor()
	if not target_name or target_name == "" then
		return
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
	local buf_name = vim.api.nvim_buf_get_name(current_buf)
	local base_path = buf_name ~= "" and vim.fs.dirname(buf_name) or nil

	-- Safely escape pattern characters in target name
	local safe_name = vim.pesc(target_name)

	-- Patterns for declaration lookup (No string.format used)
	local patterns = {
		"^#!sec:%s*" .. safe_name .. "%s*$",
		"^#!const:%s*" .. safe_name .. "%s*:",
		"^#!enum:%s*" .. safe_name .. "%s*{",
	}

	-- Search within current buffer
	for lnum, line in ipairs(lines) do
		for _, pat in ipairs(patterns) do
			if line:find(pat) then
				vim.api.nvim_win_set_cursor(0, { lnum, 0 })
				return
			end
		end
	end

	-- Search within imported files if not found locally
	local ast = parser.parse(lines, base_path)
	for _, import_path in ipairs(ast.imports or {}) do
		if vim.fn.filereadable(import_path) == 1 then
			local imp_lines = vim.fn.readfile(import_path)
			for lnum, line in ipairs(imp_lines) do
				for _, pat in ipairs(patterns) do
					if line:find(pat) then
						vim.cmd("edit " .. vim.fn.fnameescape(import_path))
						vim.api.nvim_win_set_cursor(0, { lnum, 0 })
						return
					end
				end
			end
		end
	end

	vim.notify("Definition not found for: " .. target_name, vim.log.levels.WARN)
end

--- 2. gr: Find References (Quickfix list)
function M.find_references()
	local target_name, _ = get_identifier_under_cursor()
	if not target_name or target_name == "" then
		return
	end

	local qf_list = {}
	local current_buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
	local buf_name = vim.api.nvim_buf_get_name(current_buf)
	local base_path = buf_name ~= "" and vim.fs.dirname(buf_name) or nil

	local safe_name = vim.pesc(target_name)

	local function search_in_file(filepath, file_lines)
		local ref_pattern = "#%$" .. safe_name .. "[;:}]"
		local decl_pattern1 = "#!sec:" .. safe_name
		local decl_pattern2 = "#!const:" .. safe_name
		local decl_pattern3 = "#!enum:" .. safe_name

		for lnum, line in ipairs(file_lines) do
			if
				line:find(ref_pattern)
				or line:find(decl_pattern1)
				or line:find(decl_pattern2)
				or line:find(decl_pattern3)
			then
				table.insert(qf_list, {
					filename = filepath,
					lnum = lnum,
					text = trim(line),
				})
			end
		end
	end

	-- Search in active buffer
	search_in_file(buf_name ~= "" and buf_name or "[Current Buffer]", lines)

	-- Search in imported files
	local ast = parser.parse(lines, base_path)
	for _, import_path in ipairs(ast.imports or {}) do
		if vim.fn.filereadable(import_path) == 1 then
			local imp_lines = vim.fn.readfile(import_path)
			search_in_file(import_path, imp_lines)
		end
	end

	if #qf_list > 0 then
		vim.fn.setqflist(qf_list, "r")
		vim.cmd("copen")
	else
		vim.notify("No references found for: " .. target_name, vim.log.levels.WARN)
	end
end

--- 3. <leader>rn: Symbol Rename (Supports Multi-file via Imports)
function M.rename()
	local target_name, _ = get_identifier_under_cursor()
	if not target_name or target_name == "" then
		return
	end

	local new_name = vim.fn.input("Rename '" .. target_name .. "' to: ", target_name)
	if new_name == "" or new_name == target_name then
		return
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
	local buf_name = vim.api.nvim_buf_get_name(current_buf)
	local base_path = buf_name ~= "" and vim.fs.dirname(buf_name) or nil

	-- 1. Get all target files (Current buffer + Imported files)
	local target_files = {}
	if buf_name ~= "" then
		target_files[buf_name] = true
	end

	local ast = parser.parse(lines, base_path)
	for _, import_path in ipairs(ast.imports or {}) do
		if vim.fn.filereadable(import_path) == 1 then
			target_files[import_path] = true
		end
	end

	-- 2. Process replacement for a given set of lines
	local function process_lines(file_lines)
		local updated_lines = {}
		local changed = false
		local count = 0

		for _, line in ipairs(file_lines) do
			local new_line = line
			new_line = new_line:gsub("#!sec:" .. target_name .. "(%s*)$", "#!sec:" .. new_name .. "%1")
			new_line = new_line:gsub("#!const:" .. target_name .. "(%s*:)", "#!const:" .. new_name .. "%1")
			new_line = new_line:gsub("#!enum:" .. target_name .. "(%s*%{)", "#!enum:" .. new_name .. "%1")
			new_line = new_line:gsub("#%$" .. target_name .. "([;:])", "#$" .. new_name .. "%1")

			if new_line ~= line then
				changed = true
				count = count + 1
			end
			table.insert(updated_lines, new_line)
		end

		return updated_lines, changed, count
	end

	-- 3. Execute replacement across all identified files
	local total_occurrences = 0
	local total_files = 0

	for filepath, _ in pairs(target_files) do
		-- Handle active buffer
		if filepath == buf_name then
			local updated, changed, count = process_lines(lines)
			if changed then
				vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, updated)
				total_occurrences = total_occurrences + count
				total_files = total_files + 1
			end
		else
			-- Handle external imported files
			local imp_lines = vim.fn.readfile(filepath)
			local updated, changed, count = process_lines(imp_lines)
			if changed then
				vim.fn.writefile(updated, filepath)
				total_occurrences = total_occurrences + count
				total_files = total_files + 1

				-- Reload buffer if the external file happens to be open in another window/tab
				local external_buf = vim.fn.bufnr(filepath)
				if external_buf ~= -1 and vim.api.nvim_buf_is_loaded(external_buf) then
					vim.api.nvim_buf_call(external_buf, function()
						vim.cmd("edit!")
					end)
				end
			end
		end
	end

	vim.notify(
		"Renamed " .. total_occurrences .. " occurrence(s) across " .. total_files .. " file(s)",
		vim.log.levels.INFO
	)
end

return M

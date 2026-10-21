-- lua/flat/navigation.lua
local parser = require("flat.parser")
local M = {}

local function extract_import_path(line, next_line, current_file)
	local current_dir = vim.fn.fnamemodify(current_file, ":h")
	local import_path = nil

	-- 新インポート構文の次行 (|from(path)) からパスを抽出
	if next_line then
		import_path = next_line:match("^%s*|%s*from%((.-)%s*%)%s*$")
	end
	-- 従来型・1行型
	if not import_path then
		import_path = line:match("^#!import:%s*{.-}%s+from%s+(.-)%s*$") or line:match("^#!%s*import:%s*(.-)%s*$")
	end

	if import_path then
		import_path = vim.trim(import_path)
		local target_path = import_path
		if vim.startswith(import_path, "./") then
			target_path = current_dir .. "/" .. import_path:sub(3)
		elseif not vim.startswith(import_path, "/") then
			target_path = current_dir .. "/" .. import_path
		end
		return vim.fn.fnamemodify(target_path, ":p")
	end
	return nil
end

function M.goto_definition()
	local bufnr = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local line = lines[row] or ""
	local next_line = lines[row + 1]
	local current_file = vim.api.nvim_buf_get_name(bufnr)

	-- 1. #!import: または |from(...) の行にいる場合の処理
	if line:match("^#!import:") or line:match("^%s*|%s*from%(") then
		local target_line = line
		local target_next = next_line
		if line:match("^%s*|%s*from%(") and row > 1 then
			target_line = lines[row - 1]
			target_next = line
		end

		local target_path = extract_import_path(target_line, target_next, current_file)
		if target_path and vim.fn.filereadable(target_path) == 1 then
			vim.cmd("edit " .. vim.fn.fnameescape(target_path))
		else
			vim.notify(
				"インポートファイルが見つかりません: " .. tostring(target_path),
				vim.log.levels.WARN
			)
		end
		return
	end

	-- 2. カーソル位置にある `#$ ... ;` の参照先を探す
	local ref_name = nil
	local pos = 1
	while pos <= #line do
		local c2 = line:sub(pos, pos + 1)
		if c2 == "#$" then
			local start_pos = pos
			local semi = nil
			local search_pos = pos + 2
			while search_pos <= #line do
				local s_char = line:sub(search_pos, search_pos)
				if s_char == "\\" then
					search_pos = search_pos + 2
				elseif s_char == ";" then
					semi = search_pos
					break
				else
					search_pos = search_pos + 1
				end
			end
			if semi then
				if (col + 1) >= start_pos and (col + 1) <= semi then
					ref_name = line:sub(start_pos + 2, semi - 1)
					break
				end
				pos = semi + 1
			else
				break
			end
		else
			pos = pos + 1
		end
	end

	if not ref_name then
		return
	end

	if vim.startswith(ref_name, "./") or vim.startswith(ref_name, "/") or ref_name:match("%.[a-zA-Z0-9]+$") then
		local current_dir = vim.fn.fnamemodify(current_file, ":h")
		local target_path = ref_name
		if vim.startswith(ref_name, "./") then
			target_path = current_dir .. "/" .. ref_name:sub(3)
		elseif not vim.startswith(ref_name, "/") then
			target_path = current_dir .. "/" .. ref_name
		end
		target_path = vim.fn.fnamemodify(target_path, ":p")

		if vim.fn.filereadable(target_path) == 1 or vim.fn.isdirectory(target_path) == 1 then
			vim.cmd("edit " .. vim.fn.fnameescape(target_path))
		else
			vim.notify("ファイルが存在しません: " .. target_path, vim.log.levels.WARN)
		end
		return
	end

	local base_name = ref_name
	local all_symbols = parser.parse_pass1(bufnr, lines, current_file)

	for _, sym in ipairs(all_symbols) do
		if sym.name == base_name then
			if sym.file == vim.fn.fnamemodify(current_file, ":p") then
				vim.api.nvim_win_set_cursor(0, { sym.line or sym.start_line, 0 })
			else
				vim.cmd("edit " .. vim.fn.fnameescape(sym.file))
				vim.api.nvim_win_set_cursor(0, { sym.line or sym.start_line, 0 })
			end
			return
		end
	end

	vim.notify("定義が見つかりません: " .. base_name, vim.log.levels.WARN)
end

return M

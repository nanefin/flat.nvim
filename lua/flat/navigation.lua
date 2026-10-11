-- lua/flat/navigation.lua
local M = {}

-- 補助関数: 指定ファイルからセクション・ブロックのシンボルを収集する
local function get_symbols_from_file(filepath)
	if vim.fn.filereadable(filepath) ~= 1 then
		return {}
	end
	local lines = vim.fn.readfile(filepath)
	local symbols = {}
	for i, line in ipairs(lines) do
		local sec_name = line:match("^%s*#!%s*section:%s*([^%|%s]+)")
		local block_name = line:match("^%s*#!%s*block:%s*([^%|%s]+)")
		local name = sec_name or block_name
		if name then
			table.insert(symbols, { name = name, line = i, file = filepath })
		end
	end
	return symbols
end

-- 補助関数: #!import: 行からインポートファイルパスの一覧を抽出する
local function get_imported_files(current_file, lines)
	local current_dir = vim.fn.fnamemodify(current_file, ":h")
	local files = {}
	for _, line in ipairs(lines) do
		local import_path = line:match("^#!%s*import:%s*(.+)$")
		if import_path then
			import_path = vim.trim(import_path)
			local target_path = import_path
			if vim.startswith(import_path, "./") then
				target_path = current_dir .. "/" .. import_path:sub(3)
			elseif not vim.startswith(import_path, "/") then
				target_path = current_dir .. "/" .. import_path
			end
			target_path = vim.fn.fnamemodify(target_path, ":p")
			table.insert(files, target_path)
		end
	end
	return files
end

function M.goto_definition()
	local bufnr = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local current_file = vim.api.nvim_buf_get_name(bufnr)

	-- 1. #!import: の行にいる場合の処理
	if line:match("^#!import:") then
		local import_path = line:match("^#!%s*import:%s*(.+)$")
		if import_path then
			import_path = vim.trim(import_path)
			local current_dir = vim.fn.fnamemodify(current_file, ":h")
			local target_path = import_path
			if vim.startswith(import_path, "./") then
				target_path = current_dir .. "/" .. import_path:sub(3)
			elseif not vim.startswith(import_path, "/") then
				target_path = current_dir .. "/" .. import_path
			end
			target_path = vim.fn.fnamemodify(target_path, ":p")

			if vim.fn.filereadable(target_path) == 1 then
				vim.cmd("edit " .. vim.fn.fnameescape(target_path))
			else
				vim.notify("インポートファイルが見つかりません: " .. target_path, vim.log.levels.WARN)
			end
			return
		end
	end

	-- 2. カーソル位置にある `#$ ... ;` (パス参照またはシンボル参照) を探す
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

	-- 3. ファイルパス参照の場合（./ やファイルパス形式）
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
			vim.notify("ファイルが存在しません: " + target_path, vim.log.levels.WARN)
		end
		return
	end

	-- 4. 通常のシンボル参照（自ファイル ＋ インポートファイルから一括検索）
	local base_name = ref_name -- block.line 廃止により ref_name 全体をシンボル名とする
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local all_symbols = {}

	-- 自ファイルのシンボル収集
	for i, current_line in ipairs(lines) do
		local sec_name = current_line:match("^%s*#!%s*section:%s*([^%|%s]+)")
		local block_name = current_line:match("^%s*#!%s*block:%s*([^%|%s]+)")
		local name = sec_name or block_name
		if name then
			table.insert(all_symbols, { name = name, line = i, file = current_file })
		end
	end

	-- インポートされた外部ファイルのシンボル収集
	local imported_files = get_imported_files(current_file, lines)
	for _, imp_file in ipairs(imported_files) do
		local imp_symbols = get_symbols_from_file(imp_file)
		for _, sym in ipairs(imp_symbols) do
			table.insert(all_symbols, sym)
		end
	end

	-- 該当シンボルを探索してジャンプ
	for _, sym in ipairs(all_symbols) do
		if sym.name == base_name then
			if sym.file == current_file then
				vim.api.nvim_win_set_cursor(0, { sym.line, 0 })
			else
				vim.cmd("edit " .. vim.fn.fnameescape(sym.file))
				vim.api.nvim_win_set_cursor(0, { sym.line, 0 })
			end
			return
		end
	end

	vim.notify("定義が見つかりません: " .. base_name, vim.log.levels.WARN)
end

return M

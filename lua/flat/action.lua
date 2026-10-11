-- lua/flat/action.lua
local parser = require("flat.parser")

local M = {}

-- 補助関数: パスの解決（./ や相対パスを現在ファイル基準に変換）
local function resolve_path(current_file, path_str)
	path_str = vim.trim(path_str)
	local current_dir = vim.fn.fnamemodify(current_file, ":h")
	local target_path = path_str
	if vim.startswith(path_str, "./") then
		target_path = current_dir .. "/" .. path_str:sub(3)
	elseif not vim.startswith(path_str, "/") then
		target_path = current_dir .. "/" .. path_str
	end
	return vim.fn.fnamemodify(target_path, ":p")
end

-- copy アクション
local function exec_copy(target_sym, body_lines)
	if #body_lines == 0 then
		vim.notify("[Flat] コピー対象の本文が存在しません", vim.log.levels.WARN)
		return false
	end
	local text = table.concat(body_lines, "\n")
	vim.fn.setreg("+", text)
	vim.fn.setreg('"', text)
	vim.notify(
		string.format("[Flat] '%s' の本文をクリップボードにコピーしました", target_sym.name),
		vim.log.levels.INFO
	)
	return true
end

-- load(パス) アクション
local function exec_load(bufnr, target_sym, body_start, body_end, path_str, current_file)
	local target_path = resolve_path(current_file, path_str)
	if vim.fn.filereadable(target_path) ~= 1 then
		vim.notify(
			string.format("[Flat] 読み込み対象のファイルが存在しません: %s", target_path),
			vim.log.levels.WARN
		)
		return false
	end

	local new_lines = vim.fn.readfile(target_path)
	vim.api.nvim_buf_set_lines(bufnr, body_start - 1, body_end, false, new_lines)
	vim.notify(
		string.format("[Flat] '%s' の本文を '%s' から読みました", target_sym.name, path_str),
		vim.log.levels.INFO
	)
	return true
end

-- save(パス) アクション
local function exec_save(body_lines, path_str, current_file)
	if #body_lines == 0 then
		vim.notify("[Flat] 保存する本文が存在しません", vim.log.levels.WARN)
		return false
	end
	local target_path = resolve_path(current_file, path_str)
	local parent_dir = vim.fn.fnamemodify(target_path, ":h")
	vim.fn.mkdir(parent_dir, "p")

	vim.fn.writefile(body_lines, target_path)
	vim.notify(string.format("[Flat] 本文を '%s' に保存しました", path_str), vim.log.levels.INFO)
	return true
end

-- save!(パス) アクション
local function exec_save_bang(bufnr, target_sym, body_start, body_end, body_lines, path_str, current_file)
	if #body_lines == 0 then
		vim.notify("[Flat] 保存する本文が存在しません", vim.log.levels.WARN)
		return false
	end

	local expected_ref = "#$" .. path_str .. ";"
	if #body_lines == 1 and vim.trim(body_lines[1]) == expected_ref then
		vim.notify(
			string.format(
				"[Flat] '%s' はすでに参照置換済みです（二重実行スキップ）",
				target_sym.name
			),
			vim.log.levels.INFO
		)
		return true
	end

	if not exec_save(body_lines, path_str, current_file) then
		return false
	end

	local new_lines = { expected_ref }
	vim.api.nvim_buf_set_lines(bufnr, body_start - 1, body_end, false, new_lines)
	vim.notify(
		string.format("[Flat] '%s' の本文を '%s' に置換しました", target_sym.name, expected_ref),
		vim.log.levels.INFO
	)
	return true
end

-- list アクション
local function exec_list(bufnr, target_sym, body_start, body_end, current_file)
	if target_sym.kind ~= "section" then
		vim.notify("[Flat] list アクションは section でのみ使用できます", vim.log.levels.WARN)
		return false
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local symbols = parser.parse_pass1(bufnr, lines, current_file)

	local listed_lines = {}
	for _, sym in ipairs(symbols) do
		if not (sym.file == current_file and sym.name == target_sym.name and sym.kind == target_sym.kind) then
			local prefix = (sym.kind == "section") and "s" or "b"
			table.insert(listed_lines, string.format("%s: #$%s;", prefix, sym.name))
		end
	end

	vim.api.nvim_buf_set_lines(bufnr, body_start - 1, body_end, false, listed_lines)
	vim.notify(
		string.format("[Flat] '%s' の本文をシンボル参照一覧で更新しました", target_sym.name),
		vim.log.levels.INFO
	)
	return true
end

-- run アクション: 本文を一時ファイルに書き出し、デフォルトの方式で実行する
local function exec_run(target_sym, body_lines, current_file)
	if #body_lines == 0 then
		vim.notify("[Flat] 実行するスクリプト（本文）が存在しません", vim.log.levels.WARN)
		return false
	end

	local temp_file = vim.fn.tempname()
	local ext = (vim.fn.has("win32") == 1) and ".bat" or ".sh"
	local script_path = temp_file .. ext
	vim.fn.writefile(body_lines, script_path)

	-- 実行コマンドの構築 (2>&1 で標準エラーと標準出力を統合)
	local cmd = {}
	if vim.fn.has("win32") == 1 then
		table.insert(cmd, "cmd.exe")
		table.insert(cmd, "/c")
		table.insert(cmd, string.format("%s 2>&1", script_path))
	else
		table.insert(cmd, vim.o.shell)
		table.insert(cmd, string.format("%s 2>&1", script_path))
	end

	vim.cmd("tabnew")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false

	local title = string.format("[Flat Run] %s", target_sym.name)
	local header = {
		title,
		string.rep("=", vim.fn.strdisplaywidth(title)),
		string.format("$ %s", table.concat(cmd, " ")),
		"",
	}
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, header)
	vim.notify(string.format("[Flat] '%s' の実行を開始しました", target_sym.name), vim.log.levels.INFO)

	vim.system(cmd, {
		text = true,
		cwd = vim.fn.fnamemodify(current_file, ":h"),
	}, function(obj)
		pcall(vim.fn.delete, script_path)

		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			local output_lines = {}
			local raw_output = obj.stdout or ""
			if raw_output ~= "" then
				for _, l in ipairs(vim.split(raw_output, "\n", { plain = true })) do
					table.insert(output_lines, l)
				end
			end

			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, output_lines)
		end)
	end)

	return true
end

-- アクション行のパースとディスパッチ
local function dispatch_action(bufnr, action_line, target_sym, body_start, body_end, body_lines, current_file)
	local cmd_str = action_line:match("^%s*|%s*(.-)%s*$")
	if not cmd_str or cmd_str == "" then
		return true
	end

	if cmd_str == "copy" then
		return exec_copy(target_sym, body_lines)
	elseif cmd_str == "list" then
		return exec_list(bufnr, target_sym, body_start, body_end, current_file)
	elseif cmd_str == "run" then
		return exec_run(target_sym, body_lines, current_file)
	elseif vim.startswith(cmd_str, "load(") and vim.endswith(cmd_str, ")") then
		local path_str = cmd_str:match("^load%((.-)%)$")
		return exec_load(bufnr, target_sym, body_start, body_end, path_str, current_file)
	elseif vim.startswith(cmd_str, "save(") and vim.endswith(cmd_str, ")") then
		local path_str = cmd_str:match("^save%((.-)%)$")
		return exec_save(body_lines, path_str, current_file)
	elseif vim.startswith(cmd_str, "save!(") and vim.endswith(cmd_str, ")") then
		local path_str = cmd_str:match("^save!%((.-)%)$")
		return exec_save_bang(bufnr, target_sym, body_start, body_end, body_lines, path_str, current_file)
	else
		vim.notify(
			string.format("[Flat] 未対応または不正なアクションです: %s", cmd_str),
			vim.log.levels.WARN
		)
		return false
	end
end

function M.run_action()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_file = vim.api.nvim_buf_get_name(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1]

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local symbols = parser.parse_pass1(bufnr, lines)

	local target_sym = nil
	for _, sym in ipairs(symbols) do
		if sym.file == current_file and row >= sym.start_line and row <= sym.end_line then
			target_sym = sym
			break
		end
	end

	if not target_sym then
		vim.notify(
			"[Flat] 有効なセクションまたはブロック内にカーソルがありません",
			vim.log.levels.WARN
		)
		return
	end

	local action_lines = {}
	local scan_idx = target_sym.start_line + 1

	while scan_idx <= target_sym.end_line do
		local line = lines[scan_idx]
		if line and line:match("^%s*|") then
			table.insert(action_lines, line)
			scan_idx = scan_idx + 1
		else
			break
		end
	end

	if #action_lines == 0 then
		vim.notify("[Flat] アクション行 (|) が定義されていません", vim.log.levels.WARN)
		return
	end

	for _, act_line in ipairs(action_lines) do
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		symbols = parser.parse_pass1(bufnr, lines)

		local current_target = nil
		for _, sym in ipairs(symbols) do
			if sym.file == current_file and sym.name == target_sym.name and sym.kind == target_sym.kind then
				current_target = sym
				break
			end
		end

		if not current_target then
			vim.notify("[Flat] 対象シンボルが見つからなくなりました", vim.log.levels.WARN)
			break
		end

		local body_start = current_target.start_line + 1
		while body_start <= current_target.end_line do
			local l = lines[body_start]
			if l and l:match("^%s*|") then
				body_start = body_start + 1
			else
				break
			end
		end
		local body_end = current_target.end_line

		local body_lines = {}
		if body_start <= body_end then
			for i = body_start, body_end do
				table.insert(body_lines, lines[i])
			end
		end

		local success = dispatch_action(bufnr, act_line, current_target, body_start, body_end, body_lines, current_file)
		if not success then
			break
		end
	end
end

function M.setup()
	vim.api.nvim_create_user_command("FlatAction", function()
		M.run_action()
	end, {})
end

return M

-- lua/flat/action.lua
local parser = require("flat.parser")

local M = {}

-- 個別のアクション: copy
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

-- アクション行の文字列（例: "| copy"）をパースして実行する
local function dispatch_action(action_line, target_sym, body_lines, bufnr)
	local cmd_str = action_line:match("^%s*|%s*(.-)%s*$")
	if not cmd_str or cmd_str == "" then
		return
	end

	if cmd_str == "copy" then
		exec_copy(target_sym, body_lines)
	else
		vim.notify(
			string.format("[Flat] 未対応または不正なアクションです: %s", cmd_str),
			vim.log.levels.WARN
		)
	end
end

-- カーソル位置のアクションを実行するエントリーポイント
function M.run_action()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] -- 1-indexed

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local symbols = parser.parse_pass1(bufnr, lines)
	local current_file = vim.api.nvim_buf_get_name(bufnr)

	-- カーソルが属するシンボル（セクション・ブロック）を特定
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

	-- 定義行直下に連続する `|` アクション行と、それ以降の本文行を抽出
	local action_lines = {}
	local body_start = target_sym.start_line + 1

	while body_start <= target_sym.end_line do
		local line = lines[body_start]
		if line and line:match("^%s*|") then
			table.insert(action_lines, line)
			body_start = body_start + 1
		else
			break
		end
	end

	if #action_lines == 0 then
		vim.notify("[Flat] アクション行 (|) が定義されていません", vim.log.levels.WARN)
		return
	end

	-- 本文の抽出
	local body_lines = {}
	for i = body_start, target_sym.end_line do
		table.insert(body_lines, lines[i])
	end

	-- 順次アクションを実行
	for _, act_line in ipairs(action_lines) do
		dispatch_action(act_line, target_sym, body_lines, bufnr)
	end
end

function M.setup()
	-- 統一コマンド :FlatAction を登録
	vim.api.nvim_create_user_command("FlatAction", function()
		M.run_action()
	end, {})
end

return M

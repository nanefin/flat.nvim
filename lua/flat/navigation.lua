local parser = require("flat.parser")

local M = {}

function M.goto_definition()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local col = cursor[2] + 1
	local line = vim.api.nvim_get_current_line()

	local ref_name = nil

	-- #$参照名; の上にカーソルがあるかチェック
	for start_pos, name, end_pos in line:gmatch("()#$([^;]+)()") do
		if col >= start_pos and col <= end_pos then
			ref_name = name:match("^([^%.]+)")
			break
		end
	end

	-- 見つからない場合は通常のカーソル下の単語を取得
	if not ref_name then
		ref_name = vim.fn.expand("<cword>")
	end

	if not ref_name or ref_name == "" then
		print("[Flat] 選択位置にシンボルが見つかりません")
		return
	end

	-- パーサーでインポート先も含めた全シンボルを取得
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local symbols = parser.parse_pass1(bufnr, lines)

	local target_sym = nil
	for _, sym in ipairs(symbols) do
		if sym.name == ref_name then
			target_sym = sym
			break
		end
	end

	if not target_sym then
		print(string.format("[Flat] シンボル '%s' の定義が見つかりません", ref_name))
		return
	end

	-- 定義元ファイルを開いて該当行へジャンプ
	vim.cmd("edit " .. vim.fn.fnameescape(target_sym.file))
	vim.api.nvim_win_set_cursor(0, { target_sym.start_line, 0 })
end

return M

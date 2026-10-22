-- lua/flat/folding.lua
local parser = require("flat.parser")
local M = {}

-- バッファごとの行番号と折り畳みレベルの対応マップを保持するキャッシュ
local fold_cache = {}

local function update_cache(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local current_file = vim.api.nvim_buf_get_name(bufnr)
	local abs_current = vim.fn.fnamemodify(current_file, ":p")
	local symbols = parser.parse_pass1(bufnr, lines)

	local line_map = {}
	for _, sym in ipairs(symbols) do
		if sym.file == abs_current then
			-- 宣言行は折り畳み開始
			line_map[sym.start_line] = ">1"
			-- 本文行はレベル 1 を維持
			for r = sym.start_line + 1, sym.end_line do
				line_map[r] = "1"
			end
		end
	end
	fold_cache[bufnr] = line_map
end

function M.foldexpr(lnum)
	local bufnr = vim.api.nvim_get_current_buf()
	local line_map = fold_cache[bufnr]

	-- キャッシュがまだ無ければその場で更新
	if not line_map then
		update_cache(bufnr)
		line_map = fold_cache[bufnr]
	end

	-- マップから高速に結果を返す（毎行パースしないため超軽量）
	return line_map and line_map[lnum] or "="
end

function M.setup(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].filetype == "flat" then
		update_cache(bufnr)

		vim.opt_local.foldmethod = "expr"
		vim.opt_local.foldexpr = "v:lua.require'flat.folding'.foldexpr(v:lnum)"
		vim.opt_local.foldlevel = 99

		-- テキスト変更や保存時にのみキャッシュを再構築する
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
			buffer = bufnr,
			callback = function()
				update_cache(bufnr)
			end,
		})
	end
end

return M

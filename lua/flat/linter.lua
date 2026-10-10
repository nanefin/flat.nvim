-- lua/flat/linter.lua
local parser = require("flat.parser")

local M = {}
local ns_id = vim.api.nvim_create_namespace("flat_diagnostic")

function M.lint(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "flat" then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local symbols = parser.parse_pass1(bufnr, lines)

	local symbol_map = {}
	for _, sym in ipairs(symbols) do
		symbol_map[sym.name] = sym
	end

	local diagnostics = {}
	for i, line in ipairs(lines) do
		for start_pos, ref_name, end_pos in line:gmatch("()#$([^;]+)()") do
			local base_name = ref_name:match("^([^%.]+)")
			if not base_name:match("^%./") and not symbol_map[base_name] then
				table.insert(diagnostics, {
					lnum = i - 1, -- 0-indexed
					col = start_pos - 1, -- 0-indexed
					end_col = end_pos - 1,
					severity = vim.diagnostic.severity.ERROR,
					message = string.format("未定義のシンボルを参照しています: %s", base_name),
					source = "flat",
				})
			end
		end
	end

	vim.diagnostic.set(ns_id, bufnr, diagnostics, {})
end

function M.setup()
	-- ファイルを開いた時やテキスト変更時にリアルタイムで診断を実行
	vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost", "TextChanged", "TextChangedI", "BufWritePost" }, {
		pattern = "*.flat",
		callback = function(args)
			M.lint(args.buf)
		end,
	})
end

return M

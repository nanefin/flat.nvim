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
	local current_file = vim.api.nvim_buf_get_name(bufnr)
	local symbols = parser.parse_pass1(bufnr, lines)

	local diagnostics = {}
	local symbol_map = {}
	local defined_local_names = {}

	-- 1. シンボル登録と名前衝突（重複）のチェック
	for _, sym in ipairs(symbols) do
		if sym.file == vim.fn.fnamemodify(current_file, ":p") then
			if defined_local_names[sym.name] then
				for i, line in ipairs(lines) do
					local kind, name = line:match("^#!(%w+):%s*([^%|%s]+)")
					if name == sym.name and i >= sym.start_line then
						table.insert(diagnostics, {
							lnum = i - 1,
							col = 0,
							end_col = #line,
							severity = vim.diagnostic.severity.ERROR,
							message = string.format(
								"シンボル名が重複して定義されています: %s",
								sym.name
							),
							source = "flat",
						})
						break
					end
				end
			else
				defined_local_names[sym.name] = true
			end
		end
		symbol_map[sym.name] = sym
	end

	-- 2. #$ 参照の検証
	for i, line in ipairs(lines) do
		if not line:match("^%s*##") then
			local len = #line
			local pos = 1
			while pos <= len do
				local char = line:sub(pos, pos)
				if char == "\\" and pos < len then
					pos = pos + 2
				else
					local c2 = line:sub(pos, pos + 1)
					if c2 == "#$" and (pos == 1 or line:sub(pos - 1, pos - 1) ~= "\\") then
						local start_pos = pos
						local semi = nil
						local search_pos = pos + 2
						while search_pos <= len do
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
							local ref_content = line:sub(pos + 2, semi - 1)
							if not vim.startswith(ref_content, "./") then
								local base_name = ref_content
								if not symbol_map[base_name] then
									table.insert(diagnostics, {
										lnum = i - 1,
										col = start_pos - 1,
										end_col = semi,
										severity = vim.diagnostic.severity.ERROR,
										message = string.format(
											"未定義のシンボルを参照しています: %s",
											base_name
										),
										source = "flat",
									})
								end
							end
							pos = semi + 1
						else
							pos = pos + 2
						end
					else
						pos = pos + 1
					end
				end
			end
		end
	end

	vim.diagnostic.set(ns_id, bufnr, diagnostics, {})
end

function M.setup()
	vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost", "TextChanged", "TextChangedI", "BufWritePost" }, {
		pattern = "*.flat",
		callback = function(args)
			M.lint(args.buf)
		end,
	})
end

return M

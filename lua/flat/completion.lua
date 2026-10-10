local parser = require("flat.parser")

local M = {}

function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "flat",
		callback = function(args)
			vim.bo[args.buf].omnifunc = "v:lua.require'flat.completion'.complete"
		end,
	})
end

function M.complete(findstart, base)
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-indexed
	local prefix = line:sub(1, col + 1)

	-- コメント行 (##) の場合は補完を出さない
	if prefix:match("^%s*##") then
		return -3
	end

	if findstart == 1 then
		-- カーソル位置から左に向かって '#' を探し、その位置を正確に返す
		for i = col + 1, 1, -1 do
			if line:sub(i, i) == "#" then
				return i - 1
			end
		end
		return -3
	else
		-- base には "#", "#!", "#$abc" などが渡される
		local items = {}

		-- 入力状況から「ディレクティブ文脈」か「参照シンボル文脈」かを厳密に判定
		local is_directive = base:match("^#!?") and not base:find("%$")
		local is_symbol = base:match("^#$") or base:find("%$")

		-- どちらでもない（単なる "#" のみ）場合は両方の候補を許可
		if not is_directive and not is_symbol and base == "#" then
			is_directive = true
			is_symbol = true
		end

		-- 1. ディレクティブ候補 (#!...)
		if is_directive then
			local directives = {
				{ word = "#!section: ", abbr = "#!section:", menu = "[Directive]", kind = "D" },
				{ word = "#!block: ", abbr = "#!block:", menu = "[Directive]", kind = "D" },
				{ word = "#!import: ", abbr = "#!import:", menu = "[Directive]", kind = "D" },
			}
			for _, d in ipairs(directives) do
				if base == "#" or vim.startswith(d.word, base) then
					table.insert(items, d)
				end
			end
		end

		-- 2. 参照シンボル候補 (#$...)
		if is_symbol then
			local bufnr = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local symbols = parser.parse_pass1(bufnr, lines)

			for _, sym in ipairs(symbols) do
				local candidate = "#$" .. sym.name .. ";"
				if base == "#" or base == "#$" or vim.startswith(candidate, base) then
					table.insert(items, {
						word = candidate,
						abbr = candidate,
						menu = string.format("[%s: %s]", sym.kind, vim.fn.fnamemodify(sym.file, ":t")),
						kind = sym.kind == "section" and "S" or "B",
					})
				end
			end
		end

		return items
	end
end

return M

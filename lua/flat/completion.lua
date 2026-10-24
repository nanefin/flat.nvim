-- lua/flat/completion.lua
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

-- 同一ディレクトリ内の他の .flat ファイルからシンボルを収集する補助関数
local function get_external_flat_symbols(current_file)
	local current_dir = vim.fn.fnamemodify(current_file, ":h")
	local files = vim.fn.glob(current_dir .. "/*.flat", false, true)
	local symbols = {}
	local abs_current = vim.fn.fnamemodify(current_file, ":p")

	for _, filepath in ipairs(files) do
		if vim.fn.fnamemodify(filepath, ":p") ~= abs_current then
			local file = io.open(filepath, "r")
			if file then
				for line in file:lines() do
					local kind, name = line:match("^#!(%w+):%s*(.-)%s*$")
					if kind and (kind == "section" or kind == "block") then
						name = name:gsub("%s*|.*$", "")
						table.insert(symbols, {
							name = vim.trim(name),
							kind = kind,
							file = filepath,
						})
					end
				end
				file:close()
			end
		end
	end
	return symbols
end

function M.complete(findstart, base)
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-indexed

	if line:match("^%s*##") then
		return -3
	end

	if findstart == 1 then
		for i = col + 1, 1, -1 do
			local char = line:sub(i, i)
			-- 波括弧の検出を除外
			if char == "#" or char == "|" or char:match("%s") then
				if char:match("%s") then
					return i
				end
				return i - 1
			end
		end
		return 0
	else
		local items = {}
		local bufnr = vim.api.nvim_get_current_buf()
		local current_file = vim.api.nvim_buf_get_name(bufnr)
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		-- 文脈判定: #!import が行に含まれているか
		local is_import_context = line:match("^#!import") ~= nil

		-- 1. #!import の中でインポート可能な外部シンボル候補を提案
		if is_import_context then
			local ext_symbols = get_external_flat_symbols(current_file)
			for _, sym in ipairs(ext_symbols) do
				local candidate = sym.name
				if base == "" or vim.startswith(candidate, base) or base:match(",") then
					table.insert(items, {
						word = candidate,
						abbr = candidate,
						menu = string.format("[Import %s: %s]", sym.kind, vim.fn.fnamemodify(sym.file, ":t")),
						kind = sym.kind == "section" and "S" or "B",
					})
				end
			end
		end

		-- 2. ディレクティブ候補 (#!)
		if not is_import_context and (base == "" or vim.startswith("#!", base) or base:match("^#")) then
			local directives = {
				{ word = "#!section: ", abbr = "#!section:", menu = "[Directive]", kind = "D" },
				{ word = "#!block: ", abbr = "#!block:", menu = "[Directive]", kind = "D" },
				{ word = "#!import: ", abbr = "#!import: symbol", menu = "[Directive]", kind = "D" },
			}
			for _, d in ipairs(directives) do
				if base == "" or vim.startswith(d.word, base) or vim.startswith(base, "#") then
					table.insert(items, d)
				end
			end
		end

		-- 3. アクション候補 (|)
		if not is_import_context and (base == "" or vim.startswith("|", base) or base:match("^%|")) then
			local actions = {
				{ word = "|from()", abbr = "|from(path)", menu = "[Action]", kind = "A" },
				{ word = "|copy", abbr = "|copy", menu = "[Action]", kind = "A" },
				{ word = "|list", abbr = "|list", menu = "[Action]", kind = "A" },
				{ word = "|run(bash)", abbr = "|run(cmd)", menu = "[Action]", kind = "A" },
			}
			for _, a in ipairs(actions) do
				if base == "" or vim.startswith(a.word, base) or vim.startswith(base, "|") then
					table.insert(items, a)
				end
			end
		end

		-- 4. 通常のシンボル参照候補 (#$...)
		if not is_import_context then
			local symbols = parser.parse_pass1(bufnr, lines)
			for _, sym in ipairs(symbols) do
				local candidate = "#$" .. sym.name .. ";"
				if base == "" or vim.startswith(candidate, base) or base:match("%$") then
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

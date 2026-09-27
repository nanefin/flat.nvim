local M = {}

function M.attach(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	vim.bo[bufnr].omnifunc = "v:lua.require'flat.completion'.omni"

	local has_cmp, cmp = pcall(require, "cmp")
	if has_cmp and not M._cmp_registered then
		M._cmp_registered = true

		local Source = {}
		Source.new = function()
			return setmetatable({}, { __index = Source })
		end
		Source.get_trigger_characters = function()
			return { "#", "!", "*", "$", ":" }
		end
		Source.get_keyword_pattern = function()
			return [[\%(\k\|[^\x00-\x7F]\)\+]]
		end

		Source.complete = function(_, params, callback)
			local line_before = params.context.cursor_line:sub(1, params.context.cursor.col)

			local s = nil
			local search_pos = 1
			while true do
				local found = line_before:find("#", search_pos)
				if not found then
					break
				end
				if found == 1 or line_before:sub(found - 1, found - 1) ~= "\\" then
					if not line_before:sub(found):find(";") then
						s = found
					end
				end
				search_pos = found + 1
			end

			if not s then
				callback({ items = {}, incomplete = false })
				return
			end

			local typed = line_before:sub(s)
			local parser = require("flat.parser")
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local buf_name = vim.api.nvim_buf_get_name(0)
			local base_path = buf_name ~= "" and vim.fs.dirname(buf_name) or nil
			local ast = parser.parse(lines, base_path)
			local items = {}

			local enum_key = typed:match("^#%$([%w_]+):")
			if enum_key and ast.enums[enum_key] then
				for _, val in ipairs(ast.enums[enum_key]) do
					table.insert(items, {
						label = val .. ";",
						insertText = val .. ";",
						kind = cmp.lsp.CompletionItemKind.Value,
						detail = "[" .. enum_key .. " Element]",
					})
				end
				callback({ items = items, incomplete = false })
				return
			end

			local syntax_candidates = {
				{ label = "##", insertText = "# ", detail = "[Comment]", kind = cmp.lsp.CompletionItemKind.Snippet },
				{
					label = "#!sec:",
					insertText = "!sec:",
					detail = "[Header]",
					kind = cmp.lsp.CompletionItemKind.Keyword,
				},
				{
					label = "#!const:",
					insertText = "!const:",
					detail = "[Constant Definition]",
					kind = cmp.lsp.CompletionItemKind.Keyword,
				},
				{
					label = "#!enum:",
					insertText = "!enum:",
					detail = "[Enum Definition]",
					kind = cmp.lsp.CompletionItemKind.Keyword,
				},
				{
					label = "#!empty",
					insertText = "!empty",
					detail = "[Directive]",
					kind = cmp.lsp.CompletionItemKind.Keyword,
				},
				{
					label = "#!import:",
					insertText = "!import:",
					detail = "[File Import]",
					kind = cmp.lsp.CompletionItemKind.Keyword,
				},
				{ label = "#*", insertText = "*", detail = "[Decoration]", kind = cmp.lsp.CompletionItemKind.Operator },
			}

			for _, item in ipairs(syntax_candidates) do
				if typed == "#" or item.label:find("^" .. vim.pesc(typed)) then
					local insert_text = (typed == "#") and item.insertText or item.label:sub(#typed + 1)
					table.insert(items, {
						label = item.label,
						insertText = insert_text,
						kind = item.kind,
						detail = item.detail,
					})
				end
			end

			if typed == "#" or typed:sub(1, 2) == "#$" or typed:sub(1, 2) == "#!" then
				for _, sec in ipairs(ast.sections or {}) do
					local full_label = "#$" .. sec
					if typed == "#" or full_label:find("^" .. vim.pesc(typed)) then
						local prefix = (typed == "#" and "$ " or (typed == "#$" and " " or ""))
						table.insert(items, {
							label = full_label,
							insertText = prefix .. sec .. ";",
							kind = cmp.lsp.CompletionItemKind.Folder,
							detail = "[Section Ref]",
						})
					end
				end

				for key, val in pairs(ast.consts or {}) do
					local full_label = "#$" .. key
					if typed == "#" or full_label:find("^" .. vim.pesc(typed)) then
						local prefix = (typed == "#" and "$" or "")
						table.insert(items, {
							label = full_label,
							insertText = prefix .. key .. ";",
							kind = cmp.lsp.CompletionItemKind.Constant,
							detail = "[Const Ref: " .. val .. "]",
						})
					end
				end

				for key in pairs(ast.enums or {}) do
					local full_label = "#$" .. key
					if typed == "#" or full_label:find("^" .. vim.pesc(typed)) then
						local prefix = (typed == "#" and "$" or "")
						table.insert(items, {
							label = full_label,
							insertText = prefix .. key .. ":",
							kind = cmp.lsp.CompletionItemKind.Enum,
							detail = "[Enum Ref]",
						})
					end
				end
			end

			callback({ items = items, incomplete = false })
		end

		cmp.register_source("flat", Source.new())
		local config = cmp.get_config()
		local sources = config.sources or {}
		table.insert(sources, { name = "flat", keyword_length = 1 })
		cmp.setup.buffer({ sources = sources })
	end
end

function M.omni(findstart, base)
	if findstart == 1 then
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local line_before = line:sub(1, col)

		local s = nil
		local search_pos = 1
		while true do
			local found = line_before:find("#", search_pos)
			if not found then
				break
			end
			if found == 1 or line_before:sub(found - 1, found - 1) ~= "\\" then
				if not line_before:sub(found):find(";") then
					s = found
				end
			end
			search_pos = found + 1
		end

		if s then
			return s + 1
		end
		return -1
	else
		local parser = require("flat.parser")
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local ast = parser.parse(lines)
		local items, search_base = {}, base or ""

		for _, sec in ipairs(ast.sections or {}) do
			if sec:find("^" .. vim.pesc(search_base)) then
				table.insert(items, { word = "$" .. sec .. ";", abbr = "#$" .. sec, menu = "[Section Ref]" })
			end
		end

		for key, val in pairs(ast.consts or {}) do
			if key:find("^" .. vim.pesc(search_base)) then
				table.insert(
					items,
					{ word = "$" .. key .. ";", abbr = "#$" .. key, menu = "[Const Ref: " .. val .. "]" }
				)
			end
		end

		for key in pairs(ast.enums or {}) do
			if key:find("^" .. vim.pesc(search_base)) then
				table.insert(items, { word = "$" .. key .. ":", abbr = "#$" .. key, menu = "[Enum Ref]" })
			end
		end

		return items
	end
end

return M

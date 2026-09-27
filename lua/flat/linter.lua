local M = {}
local diagnostic_ns = vim.api.nvim_create_namespace("flat_linter")

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function M.attach(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local parser = require("flat.parser")

	local function check_inline_refs(line, idx, start_pos, scope_consts, scope_enums, diagnostics)
		local line_len = #line
		local search_pos = start_pos or 1

		while search_pos <= line_len do
			local hash_pos = nil
			local curr = search_pos

			while curr <= line_len do
				local pos = line:find("#%$", curr)
				if not pos then
					break
				end
				if pos == 1 or line:sub(pos - 1, pos - 1) ~= "\\" then
					hash_pos = pos
					break
				end
				curr = pos + 2
			end

			if not hash_pos then
				break
			end

			local semi_pos = nil
			curr = hash_pos + 2
			while curr <= line_len do
				local s_char = line:sub(curr, curr)
				if s_char == "\\" then
					curr = curr + 2
				elseif s_char == ";" then
					semi_pos = curr
					break
				else
					curr = curr + 1
				end
			end

			if not semi_pos then
				table.insert(diagnostics, {
					lnum = idx,
					col = hash_pos - 1,
					end_lnum = idx,
					end_col = line_len,
					severity = vim.diagnostic.severity.ERROR,
					message = "Syntax Error: Missing terminating ';'",
					source = "flat-linter",
				})
				break
			else
				local raw_content = line:sub(hash_pos + 2, semi_pos - 1)
				local content = trim(raw_content:gsub("\\(.)", "%1"))
				local start_col, end_col = hash_pos - 1, semi_pos

				if content == "" then
					table.insert(diagnostics, {
						lnum = idx,
						col = start_col,
						end_lnum = idx,
						end_col = end_col,
						severity = vim.diagnostic.severity.ERROR,
						message = "Syntax Error: Empty reference",
						source = "flat-linter",
					})
				elseif not content:find(":") then
					if not scope_consts[content] then
						table.insert(diagnostics, {
							lnum = idx,
							col = start_col,
							end_lnum = idx,
							end_col = end_col,
							severity = vim.diagnostic.severity.ERROR,
							message = string.format("Undefined Reference '%s'", content),
							source = "flat-linter",
						})
					end
				else
					local colon_idx = content:find(":")
					local key = trim(content:sub(1, colon_idx - 1))
					local val = trim(content:sub(colon_idx + 1))

					if not scope_enums[key] then
						table.insert(diagnostics, {
							lnum = idx,
							col = start_col,
							end_lnum = idx,
							end_col = end_col,
							severity = vim.diagnostic.severity.ERROR,
							message = string.format("Undefined Enum '%s'", key),
							source = "flat-linter",
						})
					elseif val ~= "" and not vim.tbl_contains(scope_enums[key] or {}, val) then
						table.insert(diagnostics, {
							lnum = idx,
							col = start_col,
							end_lnum = idx,
							end_col = end_col,
							severity = vim.diagnostic.severity.WARN,
							message = string.format("Invalid enum value '%s' for key '%s'", val, key),
							source = "flat-linter",
						})
					end
				end
				search_pos = semi_pos + 1
			end
		end
	end

	local function lint()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local buf_name = vim.api.nvim_buf_get_name(bufnr)
		local base_path = buf_name ~= "" and vim.fs.dirname(buf_name) or nil
		local ast = parser.parse(lines, base_path)
		local diagnostics = {}

		local scope_consts = {}
		local scope_enums = {}

		for _, import_path in ipairs(ast.imports or {}) do
			if vim.fn.filereadable(import_path) == 1 then
				local imp_lines = vim.fn.readfile(import_path)
				local imp_ast = parser.parse(imp_lines, vim.fs.dirname(import_path))
				for k, v in pairs(imp_ast.consts or {}) do
					scope_consts[k] = v
				end
				for k, v in pairs(imp_ast.enums or {}) do
					scope_enums[k] = v
				end
			end
		end

		for line_idx, line in ipairs(lines) do
			local idx = line_idx - 1
			local trimmed = trim(line)

			if trimmed:sub(1, 2) ~= "##" and trimmed ~= "" then
				if trimmed:find("^#!sec:") then
					local name = trim(trimmed:sub(7))
					if ast.duplicates and ast.duplicates[name] then
						table.insert(diagnostics, {
							lnum = idx,
							col = 0,
							end_lnum = idx,
							end_col = #line,
							severity = vim.diagnostic.severity.ERROR,
							message = string.format("Duplicate identifier '%s'", name),
							source = "flat-linter",
						})
					end
				elseif trimmed:find("^#!const:") then
					local body = trimmed:sub(9)
					local name, val = body:match("^([%w_]+)%s*:%s*(.*)$")
					if name then
						name = trim(name)
						if ast.duplicates and ast.duplicates[name] then
							table.insert(diagnostics, {
								lnum = idx,
								col = 0,
								end_lnum = idx,
								end_col = #line,
								severity = vim.diagnostic.severity.ERROR,
								message = string.format("Duplicate identifier '%s'", name),
								source = "flat-linter",
							})
						end
						if ast.invalid_const_lengths and ast.invalid_const_lengths[name] then
							table.insert(diagnostics, {
								lnum = idx,
								col = 0,
								end_lnum = idx,
								end_col = #line,
								severity = vim.diagnostic.severity.ERROR,
								message = string.format(
									"Constant value '%s' exceeds maximum length limit (10000 chars)",
									name
								),
								source = "flat-linter",
							})
						end
					end

					local colon_pos = line:find(":", 9)
					if colon_pos then
						check_inline_refs(line, idx, colon_pos + 1, scope_consts, scope_enums, diagnostics)
					end

					if name and name ~= "" then
						scope_consts[name] = val or ""
					end
				elseif trimmed:find("^#!enum:") then
					local rest = trimmed:sub(8)
					local name = trim(rest:match("^([%w_]+)") or "")
					if name ~= "" then
						if ast.duplicates and ast.duplicates[name] then
							table.insert(diagnostics, {
								lnum = idx,
								col = 0,
								end_lnum = idx,
								end_col = #line,
								severity = vim.diagnostic.severity.ERROR,
								message = string.format("Duplicate identifier '%s'", name),
								source = "flat-linter",
							})
						end
						scope_enums[name] = (ast.enums and ast.enums[name]) or {}
					end

					if rest:find("[%(\\)]") then
						table.insert(diagnostics, {
							lnum = idx,
							col = 0,
							end_lnum = idx,
							end_col = #line,
							severity = vim.diagnostic.severity.ERROR,
							message = "Syntax Error: Enum definition must use '{}', not '()'",
							source = "flat-linter",
						})
					elseif not rest:find("^[%w_]+%s*%{.*%}") then
						table.insert(diagnostics, {
							lnum = idx,
							col = 0,
							end_lnum = idx,
							end_col = #line,
							severity = vim.diagnostic.severity.ERROR,
							message = "Syntax Error: Invalid Enum format. Expected '#!enum:name{val1, val2}'",
							source = "flat-linter",
						})
					end
				else
					check_inline_refs(line, idx, 1, scope_consts, scope_enums, diagnostics)
				end
			end
		end

		vim.diagnostic.set(diagnostic_ns, bufnr, diagnostics)
	end

	lint()
	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function()
			vim.schedule(lint)
		end,
	})
end

return M

local M = {}
local diagnostic_ns = vim.api.nvim_create_namespace("flat_linter")

local function trim(s)
	return s and (s:match("^%s*(.-)%s*$") or s) or ""
end

function M.attach(bufnr)
	local parser = require("flat.parser")

	local function lint()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local buf_name = vim.api.nvim_buf_get_name(bufnr)
		local base_path = buf_name ~= "" and vim.fs.dirname(buf_name) or nil
		local ast = parser.parse(lines, base_path)
		local diagnostics = {}

		for line_idx, line in ipairs(lines) do
			local idx = line_idx - 1
			local trimmed = trim(line)

			if trimmed:sub(1, 2) ~= "##" and trimmed ~= "" then
				if trimmed:find("^#!enum:") then
					local rest = trimmed:sub(8)
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
					local line_len = #line
					local search_pos = 1

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
								if not ast.section_set[content] then
									table.insert(diagnostics, {
										lnum = idx,
										col = start_col,
										end_lnum = idx,
										end_col = end_col,
										severity = vim.diagnostic.severity.ERROR,
										message = string.format("Undefined Section '%s'", content),
										source = "flat-linter",
									})
								end
							else
								local colon_idx = content:find(":")
								local key = trim(content:sub(1, colon_idx - 1))
								local val = trim(content:sub(colon_idx + 1))

								if not ast.enums[key] then
									table.insert(diagnostics, {
										lnum = idx,
										col = start_col,
										end_lnum = idx,
										end_col = end_col,
										severity = vim.diagnostic.severity.ERROR,
										message = string.format("Undefined Enum '%s'", key),
										source = "flat-linter",
									})
								elseif val ~= "" and not vim.tbl_contains(ast.enums[key] or {}, val) then
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

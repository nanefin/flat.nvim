local M = {}

local function trim(s)
	return s and (s:match("^%s*(.-)%s*$") or s) or ""
end

--- Parse lines into AST
---@param lines string[]
---@param base_path string|nil Base directory for relative imports
---@param visited table<string, boolean>|nil Cache to prevent circular imports
---@return table AST containing enums, sections, and imports
function M.parse(lines, base_path, visited)
	visited = visited or {}
	local ast = {
		enums = {},
		sections = {},
		section_set = {},
		imports = {},
	}

	for _, line in ipairs(lines) do
		local clean = trim(line)

		-- 0. Parse Import directive (#!import: path.flt)
		if clean:sub(1, 9) == "#!import:" then
			local rel_path = trim(clean:sub(10))
			if rel_path ~= "" and base_path then
				local full_path = vim.fs.normalize(base_path .. "/" .. rel_path)

				if not visited[full_path] and vim.fn.filereadable(full_path) == 1 then
					visited[full_path] = true
					table.insert(ast.imports, full_path)

					local imported_lines = vim.fn.readfile(full_path)
					local imported_dir = vim.fs.dirname(full_path)
					local imported_ast = M.parse(imported_lines, imported_dir, visited)

					for k, v in pairs(imported_ast.enums) do
						if not ast.enums[k] then
							ast.enums[k] = v
						end
					end

					for _, sec in ipairs(imported_ast.sections) do
						if not ast.section_set[sec] then
							table.insert(ast.sections, sec)
							ast.section_set[sec] = true
						end
					end
				end
			end

		-- 1. Parse Section directive (#!sec:Name)
		elseif clean:sub(1, 6) == "#!sec:" then
			local title_key = trim(clean:sub(7))
			if title_key ~= "" then
				table.insert(ast.sections, title_key)
				ast.section_set[title_key] = true
			end

		-- 2. Parse Enum definition (#!enum:Name{Val1, Val2})
		elseif clean:sub(1, 7) == "#!enum:" then
			local body = clean:sub(8)
			if not body:find("[%(\\)]") then
				local name, vals_str = body:match("^([%w_]+)%s*%{(.-)%}")
				if name and vals_str then
					name = trim(name)
					local vals = {}
					for val in vals_str:gmatch("[^,%s]+") do
						table.insert(vals, trim(val))
					end
					ast.enums[name] = vals
				end
			end
		end
	end

	return ast
end

return M

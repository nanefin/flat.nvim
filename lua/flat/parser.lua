local M = {}

local MAX_CONST_LENGTH = 10000

local function trim(s)
	return s and (s:match("^%s*(.-)%s*$") or s) or ""
end

--- Parse lines into AST (Strict Top-Down 1-pass execution: O(N))
---@param lines string[]
---@param base_path string|nil Base directory for relative imports
---@param visited table<string, boolean>|nil Cache to prevent circular imports
---@return table AST containing enums, sections, consts, duplicates, and imports
function M.parse(lines, base_path, visited)
	visited = visited or {}
	local ast = {
		enums = {},
		sections = {},
		section_set = {},
		consts = {},
		duplicates = {},
		invalid_const_lengths = {},
		imports = {},
	}

	local known_identifiers = {}

	local function check_duplicate(name)
		if known_identifiers[name] then
			ast.duplicates[name] = true
		else
			known_identifiers[name] = true
		end
	end

	for _, line in ipairs(lines) do
		local clean = trim(line)

		-- 0. Parse Import directive
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
							check_duplicate(k)
						end
					end

					for k, v in pairs(imported_ast.consts) do
						if not ast.consts[k] then
							ast.consts[k] = v
							check_duplicate(k)
						end
					end

					for _, sec in ipairs(imported_ast.sections) do
						if not ast.section_set[sec] then
							table.insert(ast.sections, sec)
							ast.section_set[sec] = true
							check_duplicate(sec)
						end
					end
				end
			end

		-- 1. Parse Section directive
		elseif clean:sub(1, 6) == "#!sec:" then
			local title_key = trim(clean:sub(7))
			if title_key ~= "" then
				table.insert(ast.sections, title_key)
				ast.section_set[title_key] = true
				check_duplicate(title_key)
			end

		-- 2. Parse Const directive (Evaluates ONLY previously defined consts without recursion)
		elseif clean:sub(1, 8) == "#!const:" then
			local body = clean:sub(9)
			local name, val = body:match("^([%w_]+)%s*:%s*(.*)$")
			if name and val then
				name = trim(name)
				val = trim(val)
				check_duplicate(name)

				-- Single pass string replacement against ALREADY DEFINED constants
				local expanded = val:gsub("#%$(%w+);", function(ref_name)
					return ast.consts[ref_name] or ("#$" .. ref_name .. ";")
				end)

				if #expanded > MAX_CONST_LENGTH then
					ast.invalid_const_lengths[name] = true
					ast.consts[name] = val
				else
					ast.consts[name] = expanded
				end
			end

		-- 3. Parse Enum definition
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
					check_duplicate(name)
				end
			end
		end
	end

	return ast
end

return M

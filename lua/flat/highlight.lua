local M = {}
local ns_id = vim.api.nvim_create_namespace("flat_highlight")

local function setup_hl_groups()
	local folded_hl = vim.api.nvim_get_hl(0, { name = "Folded", link = false })
	local cursor_hl = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
	local sec_bg = folded_hl.bg or cursor_hl.bg

	if sec_bg then
		vim.api.nvim_set_hl(0, "FlatSecBg", { bg = sec_bg, default = true })
		vim.api.nvim_set_hl(0, "FlatSecTitle", { bg = sec_bg, link = "Title", bold = true, default = true })
		vim.api.nvim_set_hl(0, "FlatSecPrefix", { bg = sec_bg, link = "PreProc", bold = true, default = true })
	else
		vim.api.nvim_set_hl(0, "FlatSecTitle", { link = "Title", bold = true, default = true })
		vim.api.nvim_set_hl(0, "FlatSecPrefix", { link = "PreProc", bold = true, default = true })
	end

	vim.api.nvim_set_hl(0, "FlatKeyword", { link = "PreProc", bold = true, default = true })
	vim.api.nvim_set_hl(0, "FlatName", { link = "Identifier", default = true })
	vim.api.nvim_set_hl(0, "FlatValue", { link = "String", default = true })
	vim.api.nvim_set_hl(0, "FlatInline", { link = "Special", default = true })
	vim.api.nvim_set_hl(0, "FlatDelimiter", { link = "Delimiter", default = true })
	vim.api.nvim_set_hl(0, "FlatComment", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "FlatEscape", { link = "SpecialChar", default = true })
end

local function highlight_inlines(bufnr, line, line_idx, start_pos)
	local len = #line
	local pos = start_pos or 1
	while pos <= len do
		local char = line:sub(pos, pos)
		if char == "\\" and pos < len then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, pos - 1, {
				end_col = pos + 1,
				hl_group = "FlatEscape",
				priority = 250,
			})
			pos = pos + 2
		else
			local c2 = line:sub(pos, pos + 1)
			if (c2 == "#*" or c2 == "#$") and (pos == 1 or line:sub(pos - 1, pos - 1) ~= "\\") then
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
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, pos - 1, {
						end_col = semi - 1,
						hl_group = "FlatInline",
						priority = 220,
					})
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, semi - 1, {
						end_col = semi,
						hl_group = "FlatDelimiter",
						priority = 220,
					})
					pos = semi + 1
				else
					pos = pos + 1
				end
			else
				pos = pos + 1
			end
		end
	end
end

function M.attach(bufnr)
	setup_hl_groups()

	local function refresh()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		for i, line in ipairs(lines) do
			local line_idx = i - 1

			if line:sub(1, 2) == "##" then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
					end_col = #line,
					hl_group = "FlatComment",
					priority = 300,
				})
			elseif line:sub(1, 6) == "#!sec:" then
				if vim.fn.hlexists("FlatSecBg") == 1 then
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
						end_col = #line,
						line_hl_group = "FlatSecBg",
						priority = 100,
					})
				end
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
					end_col = 6,
					hl_group = "FlatSecPrefix",
					priority = 200,
				})
				if #line > 6 then
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 6, {
						end_col = #line,
						hl_group = "FlatSecTitle",
						priority = 200,
					})
				end
			elseif line:sub(1, 8) == "#!const:" then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
					end_col = 8,
					hl_group = "FlatKeyword",
					priority = 200,
				})
				local rest = line:sub(9)
				local colon_pos = rest:find(":")
				if colon_pos then
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 8, {
						end_col = 8 + colon_pos - 1,
						hl_group = "FlatName",
						priority = 200,
					})
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 8 + colon_pos - 1, {
						end_col = 8 + colon_pos,
						hl_group = "FlatDelimiter",
						priority = 200,
					})
					if #rest > colon_pos then
						vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 8 + colon_pos, {
							end_col = #line,
							hl_group = "FlatValue",
							priority = 150,
						})
						-- Enable inline reference highlight inside constant values
						highlight_inlines(bufnr, line, line_idx, 8 + colon_pos + 1)
					end
				else
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 8, {
						end_col = #line,
						hl_group = "FlatName",
						priority = 200,
					})
				end
			elseif line:sub(1, 7) == "#!enum:" then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
					end_col = 7,
					hl_group = "FlatKeyword",
					priority = 200,
				})
				local rest = line:sub(8)
				local name = rest:match("^([%w_]+)")
				if name then
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 7, {
						end_col = 7 + #name,
						hl_group = "FlatName",
						priority = 200,
					})
					local bracket_pos = line:find("{", 7 + #name)
					if bracket_pos then
						vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, bracket_pos - 1, {
							end_col = bracket_pos,
							hl_group = "FlatDelimiter",
							priority = 200,
						})
						local close_pos = line:find("}", bracket_pos)
						if close_pos then
							vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, close_pos - 1, {
								end_col = close_pos,
								hl_group = "FlatDelimiter",
								priority = 200,
							})
						end
					end
				end
			elseif line:sub(1, 9) == "#!import:" then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
					end_col = 9,
					hl_group = "FlatKeyword",
					priority = 200,
				})
				if #line > 9 then
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 9, {
						end_col = #line,
						hl_group = "FlatName",
						priority = 200,
					})
				end
			elseif line:sub(1, 2) == "#!" then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
					end_col = #line,
					hl_group = "FlatKeyword",
					priority = 200,
				})
			else
				highlight_inlines(bufnr, line, line_idx, 1)
			end
		end
	end

	refresh()
	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function()
			vim.schedule(refresh)
		end,
	})
end

return M

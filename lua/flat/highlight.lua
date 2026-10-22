-- lua/flat/highlight.lua
local parser = require("flat.parser")
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

	vim.api.nvim_set_hl(0, "FlatBlockTitle", { link = "Type", bold = true, default = true })
	vim.api.nvim_set_hl(0, "FlatKeyword", { link = "PreProc", bold = true, default = true })
	vim.api.nvim_set_hl(0, "FlatName", { link = "Identifier", default = true })
	vim.api.nvim_set_hl(0, "FlatValue", { link = "String", default = true })
	vim.api.nvim_set_hl(0, "FlatDecoration", { link = "Special", bold = true, default = true })
	vim.api.nvim_set_hl(0, "FlatRef", { link = "Function", bold = true, default = true })
	vim.api.nvim_set_hl(0, "FlatDelimiter", { link = "Delimiter", default = true })
	vim.api.nvim_set_hl(0, "FlatComment", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "FlatEscape", { link = "SpecialChar", default = true })
	vim.api.nvim_set_hl(0, "FlatBlockContent", { link = "Constant", default = true })
end

local function highlight_inlines(bufnr, line, line_idx, start_pos)
	local len = #line
	local pos = start_pos or 1
	while pos <= len do
		local char = line:sub(pos, pos)
		if char == "\\" and pos < len then
			local end_c = math.min(len, pos + 2)
			pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, pos - 1, {
				end_col = end_c,
				hl_group = "FlatEscape",
				priority = 250,
			})
			pos = pos + 2
		else
			local c2 = line:sub(pos, pos + 1)
			if c2 == "#$" and (pos == 1 or line:sub(pos - 1, pos - 1) ~= "\\") then
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
					local ref_end = math.min(len, semi)
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, pos - 1, {
						end_col = ref_end,
						hl_group = "FlatRef",
						priority = 220,
					})
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, semi - 1, {
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

local function highlight_pipe_line(bufnr, line, line_idx)
	local pipe_end = line:find("|")
	if not pipe_end then
		return
	end

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, pipe_end - 1, {
		end_col = pipe_end,
		hl_group = "FlatDecoration",
		priority = 220,
	})

	local cmd_part = line:sub(pipe_end + 1)
	local cmd_name, args = cmd_part:match("^%s*(%w+)%s*(%(.-%))")
	if not cmd_name then
		cmd_name = cmd_part:match("^%s*(%w+)")
	end

	local current_pos = pipe_end
	if cmd_name then
		local c_start, c_end = line:find(cmd_name, current_pos, true)
		if c_start then
			pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, c_start - 1, {
				end_col = c_end,
				hl_group = "FlatKeyword",
				priority = 230,
			})
			current_pos = c_end
		end
	end

	if args then
		local a_start, a_end = line:find(args, current_pos, true)
		if a_start then
			pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, a_start - 1, {
				end_col = a_end,
				hl_group = "FlatValue",
				priority = 230,
			})
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
		if vim.bo[bufnr].filetype ~= "flat" then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local symbols = parser.parse_pass1(bufnr, lines)

		local line_kind_map = {}
		for _, sym in ipairs(symbols) do
			for r = sym.start_line, sym.end_line do
				line_kind_map[r] = sym.kind
			end
		end

		for i, line in ipairs(lines) do
			local line_idx = i - 1
			local line_len = #line
			local kind = line_kind_map[i] or "section"

			if line:match("^%s*##") then
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = line_len,
					hl_group = "FlatComment",
					priority = 300,
				})
			elseif line:match("^#!section:") then
				if vim.fn.hlexists("FlatSecBg") == 1 then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
						end_col = line_len,
						line_hl_group = "FlatSecBg",
						priority = 100,
					})
				end
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = 10,
					hl_group = "FlatSecPrefix",
					priority = 200,
				})
				if line_len > 10 then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 10, {
						end_col = line_len,
						hl_group = "FlatSecTitle",
						priority = 200,
					})
				end
			elseif line:match("^#!block:") then
				-- blockの宣言行には背景色を適用する
				if vim.fn.hlexists("FlatSecBg") == 1 then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
						end_col = line_len,
						line_hl_group = "FlatSecBg",
						priority = 100,
					})
				end
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = 9,
					hl_group = "FlatKeyword",
					priority = 200,
				})
				if line_len > 9 then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 9, {
						end_col = line_len,
						hl_group = "FlatBlockTitle",
						priority = 200,
					})
				end
			elseif line:match("^#!import:") then
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = 9,
					hl_group = "FlatKeyword",
					priority = 200,
				})
				highlight_inlines(bufnr, line, line_idx, 10)
			elseif line:match("^%s*|") then
				highlight_pipe_line(bufnr, line, line_idx)
			elseif line:sub(1, 2) == "#!" then
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = line_len,
					hl_group = "FlatKeyword",
					priority = 200,
				})
			else
				if kind == "block" then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
						end_col = line_len,
						hl_group = "FlatBlockContent",
						priority = 150,
					})
					highlight_inlines(bufnr, line, line_idx, 1)
				else
					if line:match("^%s*>[>]*") then
						local _, end_pos = line:find("^%s*>[>]*")
						pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
							end_col = end_pos,
							hl_group = "FlatDecoration",
							priority = 200,
						})
						highlight_inlines(bufnr, line, line_idx, end_pos + 1)
					else
						highlight_inlines(bufnr, line, line_idx, 1)
					end
				end
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

function M.setup()
	vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufReadPost" }, {
		pattern = "*.flat",
		callback = function(args)
			if vim.bo[args.buf].filetype == "flat" then
				M.attach(args.buf)
			end
		end,
	})

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "flat" then
			M.attach(bufnr)
		end
	end
end

return M

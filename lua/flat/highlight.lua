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
		vim.api.nvim_set_hl(0, "FlatBlockBg", { bg = sec_bg, default = true })
		vim.api.nvim_set_hl(0, "FlatBlockTitle", { bg = sec_bg, link = "Type", bold = true, default = true })
	else
		vim.api.nvim_set_hl(0, "FlatSecTitle", { link = "Title", bold = true, default = true })
		vim.api.nvim_set_hl(0, "FlatSecPrefix", { link = "PreProc", bold = true, default = true })
		vim.api.nvim_set_hl(0, "FlatBlockTitle", { link = "Type", bold = true, default = true })
	end

	vim.api.nvim_set_hl(0, "FlatKeyword", { link = "PreProc", bold = true, default = true })
	vim.api.nvim_set_hl(0, "FlatName", { link = "Identifier", default = true })
	vim.api.nvim_set_hl(0, "FlatValue", { link = "String", default = true })
	vim.api.nvim_set_hl(0, "FlatDecoration", { link = "Special", bold = true, default = true })
	vim.api.nvim_set_hl(0, "FlatRef", { link = "Function", bold = true, default = true })
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

		for i, line in ipairs(lines) do
			local line_idx = i - 1
			local line_len = #line

			if line:sub(1, 2) == "##" then
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = line_len,
					hl_group = "FlatComment",
					priority = 300,
				})
			elseif line:match("^#!section:") then
				local prefix_len = 10
				if vim.fn.hlexists("FlatSecBg") == 1 then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
						end_col = line_len,
						line_hl_group = "FlatSecBg",
						priority = 100,
					})
				end
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = prefix_len,
					hl_group = "FlatSecPrefix",
					priority = 200,
				})
				if line_len > prefix_len then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, prefix_len, {
						end_col = line_len,
						hl_group = "FlatSecTitle",
						priority = 200,
					})
				end
			elseif line:match("^#!block:") then
				local prefix_len = 9
				if vim.fn.hlexists("FlatBlockBg") == 1 then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
						end_col = line_len,
						line_hl_group = "FlatBlockBg",
						priority = 100,
					})
				end
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = prefix_len,
					hl_group = "FlatKeyword",
					priority = 200,
				})
				if line_len > prefix_len then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, prefix_len, {
						end_col = line_len,
						hl_group = "FlatBlockTitle",
						priority = 200,
					})
				end
			elseif line:sub(1, 9) == "#!import:" then
				local prefix_len = 9
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = prefix_len,
					hl_group = "FlatKeyword",
					priority = 200,
				})
				if line_len > prefix_len then
					pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, prefix_len, {
						end_col = line_len,
						hl_group = "FlatName",
						priority = 200,
					})
				end
			elseif line:sub(1, 2) == "#!" then
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = line_len,
					hl_group = "FlatKeyword",
					priority = 200,
				})
			elseif line:match("^%s*>[>]*") then
				-- 行頭の >, >>, >>> などのインデント記号をハイライト
				local _, end_pos = line:find("^%s*>[>]*")
				pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_idx, 0, {
					end_col = end_pos,
					hl_group = "FlatDecoration",
					priority = 200,
				})
				-- インデント以降のインライン参照（#$など）もハイライト対象にする
				highlight_inlines(bufnr, line, line_idx, end_pos + 1)
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

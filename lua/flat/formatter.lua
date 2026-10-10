-- lua/flat/formatter.lua
local M = {}

function M.format()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local formatted = {}

	for _, line in ipairs(lines) do
		-- 行末の余分な空白を削除
		local trimmed = line:gsub("%s+$", "")
		table.insert(formatted, trimmed)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
	print("[Flat] フォーマットを完了しました")
end

function M.setup()
	vim.api.nvim_create_user_command("FlatFormat", function()
		M.format()
	end, {})
end

return M

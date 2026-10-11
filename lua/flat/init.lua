-- lua/flat/init.lua
local highlight = require("flat.highlight")
local completion = require("flat.completion")
local formatter = require("flat.formatter")
local linter = require("flat.linter")
local action = require("flat.action")

local M = {}

function M.setup(opts)
	highlight.setup()
	completion.setup()
	formatter.setup()
	linter.setup()
	action.setup() -- アクション機能を有効化

	vim.api.nvim_create_user_command("FlatCheck", function()
		local bufnr = vim.api.nvim_get_current_buf()
		linter.lint(bufnr)
		print("[Flat] 診断を再チェックしました")
	end, {})
end

return M

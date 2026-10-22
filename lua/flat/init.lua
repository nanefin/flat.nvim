-- lua/flat/init.lua
local highlight = require("flat.highlight")
local completion = require("flat.completion")
local formatter = require("flat.formatter")
local linter = require("flat.linter")
local action = require("flat.action")
local folding = require("flat.folding")

local M = {}

function M.setup(opts)
	highlight.setup()
	completion.setup()
	formatter.setup()
	linter.setup()
	action.setup() -- アクション機能を有効化

	-- ファイルタイプが flat のときに折り畳み設定を適用
	vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
		pattern = "*.flat",
		callback = function(args)
			folding.setup(args.buf)
		end,
	})

	vim.api.nvim_create_user_command("FlatCheck", function()
		local bufnr = vim.api.nvim_get_current_buf()
		linter.lint(bufnr)
		print("[Flat] 診断を再チェックしました")
	end, {})
end

return M

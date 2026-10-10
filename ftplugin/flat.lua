-- コメント文字列の設定 (gcc用)
vim.bo.commentstring = "## %s"

-- 定義ジャンプ
vim.keymap.set("n", "gd", function()
	require("flat.navigation").goto_definition()
end, { buffer = true, silent = true, desc = "Flat: Goto Definition" })

-- フォーマット
vim.keymap.set("n", "<leader>lf", function()
	require("flat.formatter").format()
end, { buffer = true, silent = true, desc = "Flat: Format" })

-- 診断のホバー表示・トグル (K)
vim.keymap.set("n", "K", function()
	vim.diagnostic.open_float({ border = "rounded", focus = false })
end, { buffer = true, silent = true, desc = "Show line diagnostics" })

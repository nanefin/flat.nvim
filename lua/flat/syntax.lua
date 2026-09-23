local M = {}

function M.setup()
	-- ハイライトグループの定義
	vim.api.nvim_set_hl(0, "FlatSecPrefix", { link = "Comment", default = true }) -- #!sec: の部分（控えめな色）
	vim.api.nvim_set_hl(0, "FlatSecTitle", { link = "Title", default = true }) -- タイトル本文（見出し色）
	vim.api.nvim_set_hl(0, "FlatEmpty", { link = "Special", default = true }) -- #!emp

	-- パターン分け（行頭から#!sec:まで / それ以降）
	vim.fn.matchadd("FlatSecPrefix", "^#!sec:")
	vim.fn.matchadd("FlatSecTitle", "^#!sec:\\zs.*")
	vim.fn.matchadd("FlatEmpty", "^#!emp$")
end

return M

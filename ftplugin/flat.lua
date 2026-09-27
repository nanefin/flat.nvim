-- ftplugin/flat.lua
local opts = { buffer = true }

-- K: Diagnostics float popup
vim.keymap.set("n", "K", function()
	local _, winid = vim.diagnostic.open_float({ border = "rounded" })
	if not winid then
		vim.cmd("normal! K")
	end
end, vim.tbl_extend("force", opts, { desc = "Show line diagnostics" }))

-- gd: Goto definition
vim.keymap.set("n", "gd", function()
	require("flat.navigation").goto_definition()
end, vim.tbl_extend("force", opts, { desc = "Go to definition (flat)" }))

-- gr: Find references
vim.keymap.set("n", "gr", function()
	require("flat.navigation").find_references()
end, vim.tbl_extend("force", opts, { desc = "Find references (flat)" }))

-- <leader>rn: Rename symbol
vim.keymap.set("n", "<leader>rn", function()
	require("flat.navigation").rename()
end, vim.tbl_extend("force", opts, { desc = "Rename symbol (flat)" }))

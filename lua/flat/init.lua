local M = {}
local ns_id = vim.api.nvim_create_namespace("flat_lines")

local function update_decorations(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "flat" then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local sec_lines = {}

    for i, line in ipairs(lines) do
        if line:find("^#!sec") then
            table.insert(sec_lines, i - 1)
        end
    end

    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

    for _, line_idx in ipairs(sec_lines) do
        -- 行全体の背景色を設定
        -- テーマに合わせて以下のいずれかのグループ名を試してみてください:
        -- "DiffAdd"    : ほどよく目立つ背景（おすすめ）
        -- "DiffChange" : 落ち着いた強調背景
        -- "Visual"     : 選択領域のような背景
        -- "PmenuSel"   : アクティブな選択背景
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
            line_hl_group = "DiffAdd",
        })
    end
end

function M.setup_decorations()
    local bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
        buffer = bufnr,
        callback = function()
            update_decorations(bufnr)
        end,
    })

    update_decorations(bufnr)
end

return M

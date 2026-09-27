local M = {}

M.opts = {
	highlight = true,
	linter = true,
	completion = true,
}

function M.setup(user_opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, user_opts or {})

	local has_conform, conform = pcall(require, "conform")
	if has_conform then
		conform.formatters.flat_formatter = {
			format = function(_, _, lines, callback)
				local formatted = require("flat.formatter").format_lines(lines)
				callback(nil, formatted)
			end,
		}
	end

	local group = vim.api.nvim_create_augroup("FlatNvim", { clear = true })

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "flat",
		callback = function(ev)
			local bufnr = ev.buf
			vim.bo[bufnr].commentstring = "## %s"
			if M.opts.highlight then
				require("flat.highlight").attach(bufnr)
			end
			if M.opts.linter then
				require("flat.linter").attach(bufnr)
			end
			if M.opts.completion then
				require("flat.completion").attach(bufnr)
			end
		end,
	})

	local function create_export_command(cmd_name, target_ft, parse_fn_name)
		vim.api.nvim_create_user_command(cmd_name, function()
			local parser = require("flat.parser")
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local ast = parser.parse(lines)
			local result = parser[parse_fn_name](ast)

			local buf = vim.api.nvim_create_buf(true, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
			vim.api.nvim_set_option_value("filetype", target_ft, { buf = buf })
			vim.api.nvim_win_set_buf(0, buf)
		end, {})
	end

	create_export_command("FlatToJSON", "json", "to_json")
	create_export_command("FlatToSQL", "sql", "to_sql")
end

return M

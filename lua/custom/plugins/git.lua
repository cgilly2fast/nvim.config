local function paneLabel(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	local _, rev, path = require("codediff.core.virtual_file").parse_url(name)
	if rev then
		local version = rev == ":0" and "staged" or rev:match("^%x+$") and rev:sub(1, 7) or rev
		return " " .. path .. "  (" .. version .. ")"
	end
	if vim.bo[buf].buftype == "" and name ~= "" then
		return " " .. vim.fn.fnamemodify(name, ":.") .. "  (working tree)"
	end
end

local function labelPanes()
	local tabpage = vim.api.nvim_get_current_tabpage()
	if not require("codediff.ui.lifecycle").get_session(tabpage) then
		return
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
		local label = paneLabel(vim.api.nvim_win_get_buf(win))
		if label then
			vim.wo[win].winbar = label
		end
	end
end

local function toggleSourceControl()
	local lifecycle = require("codediff.ui.lifecycle")
	local tabpage = vim.api.nvim_get_current_tabpage()
	if lifecycle.get_session(tabpage) then
		lifecycle.close(tabpage)
	else
		vim.cmd("CodeDiff")
	end
end

return {
	"esmuellert/codediff.nvim",
	cmd = "CodeDiff",
	build = function()
		require("codediff.core.installer.libvscode_diff").install({})
		require("codediff.core.installer.watcher").ensure(function() end)
	end,
	keys = {
		{ "<C-S-g>", toggleSourceControl, mode = { "n", "t" }, desc = "Source control" },
	},
	init = function()
		vim.api.nvim_create_autocmd({ "BufWinEnter", "WinResized" }, {
			callback = function()
				vim.schedule(labelPanes)
			end,
		})
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "codediff-explorer",
			callback = function(args)
				vim.keymap.set("n", "cc", "<cmd>Git commit<cr>", { buffer = args.buf, desc = "Commit staged changes" })
			end,
		})
	end,
	opts = {},
}

local function isRebasing(root)
	local gitDir = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--absolute-git-dir" })[1]
	return vim.fn.isdirectory(gitDir .. "/rebase-merge") == 1 or vim.fn.isdirectory(gitDir .. "/rebase-apply") == 1
end

local function versionName(rev, rebasing)
	local conflictSides = rebasing
			and { [":1"] = "common base", [":2"] = "branch you are rebasing onto", [":3"] = "your commit" }
		or { [":1"] = "common base", [":2"] = "your branch", [":3"] = "incoming branch" }
	if conflictSides[rev] then
		return conflictSides[rev] .. ", read-only"
	end
	if rev == ":0" then
		return "staged"
	end
	return rev:match("^%x+$") and rev:sub(1, 7) or rev
end

local function paneLabel(buf, session, rebasing)
	local name = vim.api.nvim_buf_get_name(buf)
	local _, rev, path = require("codediff.core.virtual_file").parse_url(name)
	if rev then
		return " " .. path .. "  (" .. versionName(rev, rebasing) .. ")"
	end
	if vim.bo[buf].buftype == "" and name ~= "" then
		local relative = vim.fn.fnamemodify(name, ":.")
		if buf == session.result_bufnr then
			return " " .. relative .. "  (RESULT: edit here, :w saves)"
		end
		return " " .. relative .. "  (working tree)"
	end
end

local function labelPanes()
	local tabpage = vim.api.nvim_get_current_tabpage()
	local session = require("codediff.ui.lifecycle").get_session(tabpage)
	if not session then
		return
	end
	local rebasing = session.result_bufnr ~= nil and isRebasing(vim.fn.getcwd())
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
		local label = paneLabel(vim.api.nvim_win_get_buf(win), session, rebasing)
		if label then
			vim.wo[win].winbar = label
		end
	end
end

local function tabLabel(tabpage)
	local lifecycle = package.loaded["codediff.ui.lifecycle"]
	if lifecycle and lifecycle.get_session(tabpage) then
		return "Source control"
	end
	local current = vim.api.nvim_tabpage_get_win(tabpage)
	local wins = vim.list_extend({ current }, vim.api.nvim_tabpage_list_wins(tabpage))
	for _, win in ipairs(wins) do
		local buf = vim.api.nvim_win_get_buf(win)
		local name = vim.api.nvim_buf_get_name(buf)
		if vim.bo[buf].buftype == "" and name ~= "" then
			return vim.fn.fnamemodify(name, ":t")
		end
	end
	return "[No Name]"
end

function _G.TabLabels()
	local parts = {}
	for index, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
		local highlight = tabpage == vim.api.nvim_get_current_tabpage() and "%#TabLineSel#" or "%#TabLine#"
		table.insert(parts, highlight .. "%" .. index .. "T " .. index .. " " .. tabLabel(tabpage) .. " ")
	end
	return table.concat(parts) .. "%#TabLineFill#%T"
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
		vim.o.tabline = "%!v:lua.TabLabels()"
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

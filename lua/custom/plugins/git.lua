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
		local buf = vim.api.nvim_win_get_buf(win)
		local label = paneLabel(buf, session, rebasing)
		if label then
			vim.wo[win].winbar = label
		end
		if session.result_bufnr and buf ~= session.result_bufnr and vim.bo[buf].buftype ~= "" then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd.cnoreabbrev("<buffer>", "<expr>", "w", [[getcmdtype() == ':' && getcmdline() ==# 'w' ? 'WriteMergeResult' : 'w']])
			end)
		end
	end
end

local function nearestConflict(session)
	local tracking = require("codediff.ui.conflict.tracking")
	local cursorLine = vim.api.nvim_win_get_cursor(0)[1]
	local nearest, nearestDistance
	for _, block in ipairs(session.conflict_blocks) do
		local start = tracking.is_block_active(session, block) and tracking.get_block_start_line(session, block, session.result_bufnr)
		if start and (not nearest or math.abs(start - cursorLine) < nearestDistance) then
			nearest, nearestDistance = block, math.abs(start - cursorLine)
		end
	end
	return nearest
end

local function mergeSession()
	local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
	if session and session.conflict_blocks and vim.api.nvim_get_current_buf() == session.result_bufnr then
		return session
	end
end

local function inputWindows(session)
	local windows = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if buf == session.original_bufnr then
			windows.original = win
		elseif buf == session.modified_bufnr then
			windows.modified = win
		end
	end
	return windows
end

local function alignInputsToConflict()
	local session = mergeSession()
	local block = session and nearestConflict(session)
	if not block then
		return
	end
	vim.wo.scrollbind = false
	local windows = inputWindows(session)
	for side, range in pairs({ original = block.output1_range, modified = block.output2_range }) do
		if windows[side] and range then
			vim.api.nvim_win_call(windows[side], function()
				vim.api.nvim_win_set_cursor(0, { math.max(range.start_line, 1), 0 })
				vim.cmd("normal! zz")
			end)
		end
	end
end

local function resolveNearestConflict(action)
	local session = mergeSession()
	local block = session and nearestConflict(session)
	if not block then
		return vim.notify("No unresolved conflict in this file", vim.log.levels.INFO)
	end
	local resultWin = vim.api.nvim_get_current_win()
	local windows = inputWindows(session)
	for side, range in pairs({ original = block.output1_range, modified = block.output2_range }) do
		if windows[side] and range and range.end_line > range.start_line then
			vim.api.nvim_set_current_win(windows[side])
			vim.api.nvim_win_set_cursor(0, { range.start_line, 0 })
			require("codediff.ui.conflict")[action](vim.api.nvim_get_current_tabpage())
			vim.api.nvim_set_current_win(resultWin)
			if nearestConflict(session) then
				require("codediff.ui.conflict.navigation").navigate_next_conflict(vim.api.nvim_get_current_tabpage())
				alignInputsToConflict()
			end
			return
		end
	end
end

local function focusMergeResult()
	local tabpage = vim.api.nvim_get_current_tabpage()
	local session = require("codediff.ui.lifecycle").get_session(tabpage)
	if not (session and session.result_bufnr and session.conflict_blocks) or vim.b[session.result_bufnr].mergeFocused then
		return
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
		if vim.api.nvim_win_get_buf(win) == session.result_bufnr then
			vim.b[session.result_bufnr].mergeFocused = true
			for keys, action in pairs({ co = "accept_current", ct = "accept_incoming", cb = "accept_both", cx = "discard" }) do
				vim.keymap.set("n", "<leader>" .. keys, function()
					resolveNearestConflict(action)
				end, { buffer = session.result_bufnr, desc = action:gsub("_", " ") })
			end
			vim.api.nvim_set_current_win(win)
			vim.api.nvim_win_set_cursor(win, { 1, 0 })
			require("codediff.ui.conflict.navigation").navigate_next_conflict(tabpage)
			alignInputsToConflict()
			return
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
		vim.api.nvim_create_user_command("WriteMergeResult", function()
			local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
			if not (session and session.result_bufnr) then
				return vim.notify("No merge result pane in this tab", vim.log.levels.WARN)
			end
			vim.api.nvim_buf_call(session.result_bufnr, function()
				vim.cmd("write")
			end)
		end, {})
		vim.api.nvim_create_autocmd({ "BufWinEnter", "WinResized" }, {
			callback = function()
				vim.schedule(labelPanes)
				vim.defer_fn(focusMergeResult, 100)
			end,
		})
		vim.api.nvim_create_autocmd("CursorMoved", {
			callback = alignInputsToConflict,
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

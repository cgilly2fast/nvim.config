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
			local tracking = require("codediff.ui.conflict.tracking")
			local remaining = #vim.tbl_filter(function(block)
				return tracking.is_block_active(session, block)
			end, session.conflict_blocks or {})
			local status = remaining == 0 and "all conflicts resolved: :w, then - on the file in the list"
				or remaining .. (remaining == 1 and " conflict" or " conflicts") .. " left"
			return " " .. relative .. "  RESULT (" .. status .. ")"
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
		if vim.bo[buf].buftype ~= "" and vim.api.nvim_buf_get_name(buf):match("^codediff:") then
			vim.keymap.set("n", "gd", function()
				vim.notify("This pane is a version from git, so it has no go-to-definition. Use gd in the working file's pane.")
			end, { buffer = buf, desc = "Go to definition (not available here)" })
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
	if not (session and session.result_bufnr and session.conflict_blocks) then
		return false
	end
	if session.focusedResult == session.result_bufnr then
		return true
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
		if vim.api.nvim_win_get_buf(win) == session.result_bufnr then
			session.focusedResult = session.result_bufnr
			for keys, action in pairs({ co = "accept_current", ct = "accept_incoming", cb = "accept_both", cx = "discard" }) do
				vim.keymap.set("n", "<leader>" .. keys, function()
					resolveNearestConflict(action)
				end, { buffer = session.result_bufnr, desc = action:gsub("_", " ") })
			end
			vim.api.nvim_set_current_win(win)
			vim.api.nvim_win_set_cursor(win, { 1, 0 })
			require("codediff.ui.conflict.navigation").navigate_next_conflict(tabpage)
			alignInputsToConflict()
			return true
		end
	end
	return false
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

local function focusMergeResultWhenReady(attempt)
	if focusMergeResult() or attempt >= 30 then
		return
	end
	vim.defer_fn(function()
		focusMergeResultWhenReady(attempt + 1)
	end, 100)
end

local function gitRoot()
	local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
	return vim.v.shell_error == 0 and root or nil
end

local function refreshSourceControl()
	if package.loaded["codediff.ui.refresh"] then
		require("codediff.ui.refresh").request(vim.api.nvim_get_current_tabpage(), { full = true })
		require("custom.git_graph").refresh()
	end
end

local function runGit(root, args, done)
	local command = vim.list_extend({ "git", "-C", root }, args)
	vim.system(command, { text = true, env = { GIT_EDITOR = "true", GIT_TERMINAL_PROMPT = "0" } }, function(result)
		vim.schedule(function()
			done(result)
		end)
	end)
end

local function reportFailure(title, result)
	local output = vim.trim((result.stdout or "") .. "\n" .. (result.stderr or ""))
	vim.notify(title .. " failed:\n" .. output, vim.log.levels.ERROR)
end

local function openCommitBox(title, message, onSubmit)
	local input = require("nui.input")({
		relative = "editor",
		position = { row = 2, col = "50%" },
		size = { width = math.min(90, vim.o.columns - 4) },
		border = {
			style = "rounded",
			text = { top = " " .. title .. " ", bottom = " Enter to commit · Esc to cancel ", bottom_align = "right" },
		},
	}, {
		default_value = message,
		on_submit = function(value)
			value = vim.trim(value)
			if value == "" then
				return vim.notify("Commit message is empty, nothing committed", vim.log.levels.WARN)
			end
			onSubmit(value)
		end,
	})
	input:mount()
	for _, mode in ipairs({ "i", "n" }) do
		input:map(mode, "<Esc>", function()
			input:unmount()
		end)
	end
end

local function continueRebase(root)
	runGit(root, { "rebase", "--continue" }, function(result)
		refreshSourceControl()
		if result.code ~= 0 then
			return reportFailure("Rebase continue", result)
		end
		vim.notify(isRebasing(root) and "Next commit has conflicts: resolve them, then commit again" or "Rebase finished")
	end)
end

local function commit()
	local root = gitRoot()
	if not root then
		return vim.notify("Not in a git repository", vim.log.levels.WARN)
	end
	local staged = vim.fn.systemlist({ "git", "-C", root, "diff", "--cached", "--name-only" })
	if isRebasing(root) then
		local gitDir = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--absolute-git-dir" })[1]
		local messageFile = gitDir .. "/rebase-merge/message"
		local original = vim.fn.filereadable(messageFile) == 1 and vim.fn.readfile(messageFile)[1] or ""
		return openCommitBox("Continue rebase", original, function(message)
			if message == original or #staged == 0 then
				return continueRebase(root)
			end
			runGit(root, { "commit", "-m", message }, function(result)
				if result.code ~= 0 then
					return reportFailure("Commit", result)
				end
				continueRebase(root)
			end)
		end)
	end
	if #staged == 0 then
		return vim.notify("Nothing staged: press - on a file (S for all), then commit", vim.log.levels.WARN)
	end
	local title = "Commit " .. #staged .. (#staged == 1 and " staged file" or " staged files")
	openCommitBox(title, "", function(message)
		runGit(root, { "commit", "-m", message }, function(result)
			refreshSourceControl()
			if result.code ~= 0 then
				return reportFailure("Commit", result)
			end
			vim.notify(vim.split(result.stdout, "\n")[1])
		end)
	end)
end

local function push()
	local root = gitRoot()
	if not root then
		return vim.notify("Not in a git repository", vim.log.levels.WARN)
	end
	local branch = vim.fn.systemlist({ "git", "-C", root, "branch", "--show-current" })[1]
	vim.fn.system({ "git", "-C", root, "rev-parse", "--abbrev-ref", "@{upstream}" })
	local args = vim.v.shell_error == 0 and { "push" } or { "push", "-u", "origin", "HEAD" }
	vim.notify("Pushing " .. branch .. "…")
	runGit(root, args, function(result)
		refreshSourceControl()
		if result.code ~= 0 then
			return reportFailure("Push", result)
		end
		vim.notify("Pushed " .. branch)
	end)
end

local function toggleSourceControl()
	local lifecycle = require("codediff.ui.lifecycle")
	local tabpage = vim.api.nvim_get_current_tabpage()
	if lifecycle.get_session(tabpage) then
		return lifecycle.close(tabpage)
	end
	for _, other in ipairs(vim.api.nvim_list_tabpages()) do
		local session = lifecycle.get_session(other)
		if session and require("custom.git_graph").isWorkingTree(session) then
			return vim.api.nvim_set_current_tabpage(other)
		end
	end
	vim.cmd("CodeDiff")
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
		{ "<leader>gc", commit, desc = "Git commit" },
		{ "<leader>gp", push, desc = "Git push" },
	},
	init = function()
		vim.o.tabline = "%!v:lua.TabLabels()"
		require("custom.git_graph").setup()
		vim.keymap.set("n", "<C-o>", function()
			require("custom.diff_definition").jumpBack()
		end, { desc = "Jump back (returns to the diff after gd)" })
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
				focusMergeResultWhenReady(0)
			end,
		})
		vim.api.nvim_create_autocmd("CursorMoved", {
			callback = alignInputsToConflict,
		})
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			callback = function()
				vim.schedule(labelPanes)
			end,
		})
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "codediff-explorer",
			callback = function(args)
				vim.keymap.set("n", "c", commit, { buffer = args.buf, desc = "Commit staged changes" })
				vim.keymap.set("n", "P", push, { buffer = args.buf, desc = "Push" })
			end,
		})
	end,
	opts = {},
}

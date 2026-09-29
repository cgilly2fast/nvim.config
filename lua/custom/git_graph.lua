local M = {}

local namespace = vim.api.nvim_create_namespace("git_graph")
local graphWindows = {}
local commitsOpenedFromGraph = {}

local function git(root, args)
	local result = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true }):wait()
	return result.code == 0 and vim.split(vim.trim(result.stdout), "\n", { trimempty = true }) or nil
end

function M.isWorkingTree(session)
	return session.modified_revision == nil or session.modified_revision == "WORKING"
end

local function syncStatus(root, hasUpstream)
	if not hasUpstream then
		return "not on origin yet"
	end
	local counts = git(root, { "rev-list", "--left-right", "--count", "HEAD...@{upstream}" })
	local ahead, behind = (counts and counts[1] or ""):match("(%d+)%s+(%d+)")
	local parts = {}
	if ahead and ahead ~= "0" then
		table.insert(parts, "↑" .. ahead .. " to push")
	end
	if behind and behind ~= "0" then
		table.insert(parts, "↓" .. behind .. " to pull")
	end
	return #parts > 0 and table.concat(parts, " · ") or "in sync with origin"
end

local function refHighlight(ref, remotes)
	if ref:match("^tag: ") then
		return "GitGraphTag"
	end
	for _, remote in ipairs(remotes) do
		if vim.startswith(ref, remote .. "/") then
			return "GitGraphRemote"
		end
	end
	return "GitGraphBranch"
end

local function highlightLine(buf, row, line, remotes)
	local shaStart, shaEnd = line:find("%x%x%x%x%x%x%x+")
	if not shaStart then
		return vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, { end_col = #line, hl_group = "GitGraphLines" })
	end
	vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, { end_col = shaStart - 1, hl_group = "GitGraphLines" })
	vim.api.nvim_buf_set_extmark(buf, namespace, row, shaStart - 1, { end_col = shaEnd, hl_group = "GitGraphHash" })
	local refsStart, refs = line:match("^ %(()(.-)%)", shaEnd + 1)
	if not refs then
		return
	end
	local offset = refsStart - 1
	for _, ref in ipairs(vim.split(refs, ", ", { plain = true })) do
		vim.api.nvim_buf_set_extmark(buf, namespace, row, offset, { end_col = offset + #ref, hl_group = refHighlight(ref, remotes) })
		offset = offset + #ref + 2
	end
end

local function render(tabpage)
	local win = graphWindows[tabpage]
	local session = require("codediff.ui.lifecycle").get_session(tabpage)
	if not (win and vim.api.nvim_win_is_valid(win) and session and session.git_root) then
		return
	end
	local root = session.git_root
	local hasUpstream = git(root, { "rev-parse", "--abbrev-ref", "@{upstream}" }) ~= nil
	local lines = git(root, { "log", "--graph", "--oneline", "--decorate=short", "--color=never", "-n", "40", "HEAD", hasUpstream and "@{upstream}" or nil }) or { "No commits yet" }
	local remotes = git(root, { "remote" }) or {}
	local buf = vim.api.nvim_win_get_buf(win)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	for row, line in ipairs(lines) do
		highlightLine(buf, row - 1, line, remotes)
	end
	vim.wo[win].winbar = "%#GitGraphTitle# Graph%#WinBar#  " .. syncStatus(root, hasUpstream)
end

local function openCommit()
	local sha = vim.api.nvim_get_current_line():match("%x%x%x%x%x%x%x+")
	if not sha then
		return
	end
	local root = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage()).git_root
	if not git(root, { "rev-parse", "--verify", "-q", sha .. "^" }) then
		return vim.notify("That is the first commit, so there is nothing before it to compare with")
	end
	local lifecycle = require("codediff.ui.lifecycle")
	for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
		local session = lifecycle.get_session(tabpage)
		if session and commitsOpenedFromGraph[session.modified_revision] then
			lifecycle.close(tabpage)
		end
	end
	commitsOpenedFromGraph[git(root, { "rev-parse", sha })[1]] = true
	vim.cmd("CodeDiff " .. sha .. "^ " .. sha)
end

local function createBuffer()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = "gitgraph"
	vim.bo[buf].modifiable = false
	vim.keymap.set("n", "<CR>", openCommit, { buffer = buf, desc = "Open this commit's changes" })
	return buf
end

local function explorerWindow(tabpage)
	local lifecycle = require("codediff.ui.lifecycle")
	local session = lifecycle.get_session(tabpage)
	local explorer = session
		and M.isWorkingTree(session)
		and session.panel
		and session.panel.name == "explorer"
		and lifecycle.get_panel_view(tabpage)
	if explorer and not explorer.is_hidden and explorer.winid and vim.api.nvim_win_is_valid(explorer.winid) then
		return explorer.winid
	end
end

function M.sync(tabpage)
	local explorer = explorerWindow(tabpage)
	local graph = graphWindows[tabpage]
	local graphOpen = graph and vim.api.nvim_win_is_valid(graph)
	if explorer and not graphOpen then
		graphWindows[tabpage] = vim.api.nvim_open_win(createBuffer(), false, {
			split = "below",
			win = explorer,
			height = math.min(12, math.floor(vim.o.lines / 3)),
		})
		local win = graphWindows[tabpage]
		vim.wo[win].winfixheight = true
		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].signcolumn = "no"
		vim.wo[win].wrap = false
		vim.wo[win].cursorline = true
		render(tabpage)
	elseif graphOpen and not explorer then
		vim.api.nvim_win_close(graph, true)
		graphWindows[tabpage] = nil
	end
end

local function forgetClosedTabs()
	for tabpage in pairs(graphWindows) do
		if not vim.api.nvim_tabpage_is_valid(tabpage) then
			graphWindows[tabpage] = nil
		end
	end
end

function M.refresh()
	render(vim.api.nvim_get_current_tabpage())
end

function M.setup()
	for name, link in pairs({
		GitGraphLines = "NonText",
		GitGraphHash = "Comment",
		GitGraphBranch = "GitSignsAdd",
		GitGraphRemote = "DiagnosticInfo",
		GitGraphTag = "DiagnosticWarn",
		GitGraphTitle = "Title",
	}) do
		vim.api.nvim_set_hl(0, name, { link = link, default = true })
	end
	local function syncSoon()
		vim.schedule(function()
			forgetClosedTabs()
			for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
				M.sync(tabpage)
			end
		end)
	end
	vim.api.nvim_create_autocmd("User", { pattern = "CodeDiffOpen", callback = syncSoon })
	vim.api.nvim_create_autocmd({ "WinClosed", "BufWinEnter", "TabClosed" }, { callback = syncSoon })
	vim.api.nvim_create_autocmd({ "TabEnter", "FocusGained", "TermLeave" }, { callback = M.refresh })
end

return M

local M = {}

local returnTo

local function isDiffTab(tabpage)
	return package.loaded["codediff.ui.lifecycle"] and require("codediff.ui.lifecycle").get_session(tabpage) ~= nil
end

local function editorWindow()
	for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
		if not isDiffTab(tabpage) then
			vim.api.nvim_set_current_tabpage(tabpage)
			local current = vim.api.nvim_get_current_win()
			if vim.bo[vim.api.nvim_win_get_buf(current)].buftype == "" then
				return current
			end
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then
					vim.api.nvim_set_current_win(win)
					return win
				end
			end
			vim.cmd("vsplit | enew")
			return vim.api.nvim_get_current_win()
		end
	end
	vim.cmd("tabnew")
	vim.cmd("tabmove 0")
	return vim.api.nvim_get_current_win()
end

function M.goToDefinition()
	local diffTab = vim.api.nvim_get_current_tabpage()
	if not isDiffTab(diffTab) then
		return require("telescope.builtin").lsp_definitions()
	end
	local diffWin = vim.api.nvim_get_current_win()
	vim.lsp.buf.definition({
		on_list = function(list)
			local item = list.items[1]
			if not item then
				return vim.notify("No definition found", vim.log.levels.INFO)
			end
			local win = editorWindow()
			vim.cmd("normal! m'")
			vim.cmd.edit(vim.fn.fnameescape(item.filename))
			vim.api.nvim_win_set_cursor(win, { item.lnum, math.max(item.col - 1, 0) })
			vim.cmd("normal! zz")
			returnTo = { tab = diffTab, win = diffWin, landing = { win = win, buf = vim.api.nvim_get_current_buf(), line = item.lnum } }
		end,
	})
end

function M.jumpBack()
	local landing = returnTo and returnTo.landing
	local atLanding = landing
		and vim.api.nvim_get_current_win() == landing.win
		and vim.api.nvim_get_current_buf() == landing.buf
		and vim.api.nvim_win_get_cursor(0)[1] == landing.line
	if atLanding and vim.api.nvim_tabpage_is_valid(returnTo.tab) and isDiffTab(returnTo.tab) then
		local target = returnTo
		returnTo = nil
		vim.api.nvim_set_current_tabpage(target.tab)
		if vim.api.nvim_win_is_valid(target.win) then
			vim.api.nvim_set_current_win(target.win)
		end
		return
	end
	vim.cmd("normal! " .. vim.v.count1 .. vim.keycode("<C-o>"))
end

return M

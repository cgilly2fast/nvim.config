local function diffSession(winid)
	if not package.loaded["codediff.ui.lifecycle"] then
		return nil
	end
	return require("codediff.ui.lifecycle").get_session(vim.api.nvim_win_get_tabpage(winid))
end

local function codediffMarks(bufnr, winid)
	local session = diffSession(winid)
	if not session then
		return {}
	end
	local util = require("satellite.util")
	local marks = {}
	local function mark(first, last, highlight)
		for pos = util.row_to_barpos(winid, first - 1), util.row_to_barpos(winid, math.max(first, last) - 1) do
			table.insert(marks, { pos = pos, highlight = highlight, symbol = "│" })
		end
	end
	if session.result_bufnr then
		local tracking = require("codediff.ui.conflict.tracking")
		for _, block in ipairs(session.conflict_blocks or {}) do
			local start = tracking.is_block_active(session, block) and tracking.get_block_start_line(session, block, bufnr)
			if start then
				mark(start, start, "SatelliteCodeDiffConflict")
			end
		end
		return marks
	end
	local side = bufnr == session.original_bufnr and "original" or bufnr == session.modified_bufnr and "modified"
	if not side or not session.stored_diff_result then
		return {}
	end
	if session.layout == "inline" then
		side = "modified"
	end
	local highlight = side == "original" and "SatelliteCodeDiffDelete" or "SatelliteCodeDiffAdd"
	for _, change in ipairs(session.stored_diff_result.changes or {}) do
		mark(change[side].start_line, change[side].end_line - 1, highlight)
	end
	return marks
end

local function linkHighlights()
	vim.api.nvim_set_hl(0, "SatelliteCodeDiffAdd", { default = true, link = "GitSignsAdd" })
	vim.api.nvim_set_hl(0, "SatelliteCodeDiffDelete", { default = true, link = "GitSignsDelete" })
	vim.api.nvim_set_hl(0, "SatelliteCodeDiffConflict", { default = true, link = "DiagnosticWarn" })
end

return {
	"lewis6991/satellite.nvim",
	event = "VeryLazy",
	opts = {
		excluded_filetypes = { "neo-tree", "codediff-explorer", "toggleterm" },
	},
	config = function(_, opts)
		local handlers = require("satellite.handlers")
		require("satellite.handlers.gitsigns")
		for _, handler in ipairs(handlers.handlers) do
			if handler.name == "gitsigns" then
				local gitsignsMarks = handler.update
				handler.update = function(bufnr, winid)
					return diffSession(winid) and {} or gitsignsMarks(bufnr, winid)
				end
			end
		end
		handlers.register({
			name = "codediff",
			config = { enable = true, overlap = false, priority = 20 },
			setup = function(_, update)
				linkHighlights()
				local group = vim.api.nvim_create_augroup("satellite_codediff", {})
				vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = linkHighlights })
				vim.api.nvim_create_autocmd("User", {
					group = group,
					pattern = { "CodeDiffOpen", "CodeDiffFileSelect", "CodeDiffVirtualFileLoaded" },
					callback = update,
				})
				vim.api.nvim_create_autocmd({ "CursorHold", "TextChanged" }, { group = group, callback = update })
			end,
			update = codediffMarks,
		})
		require("satellite").setup(opts)
	end,
}

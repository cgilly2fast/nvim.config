local terminals = {}
local current = 0
local focusPanel

local function activeTerminal()
	return terminals[current]
end

local function forget(term)
	for index, candidate in ipairs(terminals) do
		if candidate == term then
			table.remove(terminals, index)
			if index < current or current > #terminals then
				current = current - 1
			end
			return
		end
	end
end

local function show(index)
	local term = activeTerminal()
	if term and term:is_open() then
		term:close()
	end
	current = index
	terminals[current]:open()
end

local function newTerminal()
	local Terminal = require("toggleterm.terminal").Terminal
	table.insert(
		terminals,
		Terminal:new({
			direction = "horizontal",
			on_exit = function(term)
				vim.schedule(function()
					local wasActive = term == activeTerminal()
					forget(term)
					if wasActive and activeTerminal() then
						focusPanel()
					end
				end)
			end,
		})
	)
	show(#terminals)
end

function focusPanel()
	local term = activeTerminal()
	if not term then
		newTerminal()
	elseif term:is_open() then
		term:focus()
	else
		term:open()
	end
end

local function hidePanel()
	local term = activeTerminal()
	if term and term:is_open() then
		term:close()
	end
end

local function killTerminal()
	local term = activeTerminal()
	if term then
		term:shutdown()
	end
end

local function cycle(step)
	if #terminals < 2 then
		return
	end
	show((current - 1 + step) % #terminals + 1)
end

local function sendToTerminal(sequence)
	return function()
		vim.api.nvim_chan_send(vim.b.terminal_job_id, sequence)
	end
end

return {
	"akinsho/toggleterm.nvim",
	version = "*",
	keys = {
		{ "<C-S-j>", focusPanel, mode = "n", desc = "Terminal panel" },
		{ "<C-S-j>", hidePanel, mode = "t", desc = "Hide terminal panel" },
		{ "<C-S-k>", "<C-\\><C-n><C-w>k", mode = "t", desc = "Focus editor above" },
		{ "<C-S-n>", newTerminal, mode = "t", desc = "New terminal" },
		{ "<C-S-w>", killTerminal, mode = "t", desc = "Kill terminal" },
		{
			"<C-o>",
			function()
				cycle(1)
			end,
			mode = "t",
			desc = "Next terminal",
		},
		{ "<C-S-u>", sendToTerminal("\27[117;6u"), mode = "t" },
		{ "<C-S-d>", sendToTerminal("\27[100;6u"), mode = "t" },
		{ "<C-M-u>", sendToTerminal("\27[117;7u"), mode = "t" },
		{ "<C-M-d>", sendToTerminal("\27[100;7u"), mode = "t" },
	},
	opts = {
		size = function()
			return math.floor(vim.o.lines * 0.35)
		end,
		shade_terminals = false,
		start_in_insert = true,
		persist_mode = false,
	},
	init = function()
		vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
			pattern = "term://*",
			command = "startinsert",
		})
	end,
}

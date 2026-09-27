local function listConflicts()
	local files = vim.fn.systemlist({ "git", "diff", "--name-only", "--diff-filter=U" })
	if vim.v.shell_error ~= 0 or #files == 0 then
		return vim.notify("No merge conflicts", vim.log.levels.INFO)
	end
	local items = {}
	for _, file in ipairs(files) do
		for lnum, line in ipairs(vim.fn.readfile(file)) do
			if line:match("^<<<<<<<") then
				table.insert(items, { filename = file, lnum = lnum, text = "conflict" })
			end
		end
	end
	vim.fn.setqflist(items, "r")
	vim.cmd("copen")
end

return {
	"akinsho/git-conflict.nvim",
	version = "*",
	event = { "BufReadPre", "BufNewFile" },
	keys = {
		{ "<leader>gx", listConflicts, desc = "[G]it conflicts: list all" },
	},
	opts = {},
}

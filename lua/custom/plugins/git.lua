local function toggleSourceControl()
	if require("diffview.lib").get_current_view() then
		vim.cmd("DiffviewClose")
	else
		vim.cmd("DiffviewOpen")
	end
end

return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{ "<C-S-g>", toggleSourceControl, mode = { "n", "t" }, desc = "Source control" },
	},
	opts = {
		keymaps = {
			file_panel = {
				{ "n", "cc", "<cmd>Git commit<cr>", { desc = "Commit staged changes" } },
			},
		},
	},
}

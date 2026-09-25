return {
	"MagicDuck/grug-far.nvim",
	cmd = "GrugFar",
	keys = {
		{
			"<leader>S",
			function()
				require("grug-far").open()
			end,
			desc = "[S]earch & replace in project",
		},
		{
			"<leader>S",
			function()
				require("grug-far").with_visual_selection()
			end,
			mode = "x",
			desc = "[S]earch & replace selection in project",
		},
		{
			"<leader>R",
			function()
				require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
			end,
			desc = "[R]eplace in this file",
		},
	},
	opts = {
		engines = {
			ripgrep = { extraArgs = "--hidden --glob=!**/.git/*" },
		},
	},
}

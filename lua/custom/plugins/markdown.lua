return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = "markdown",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "<leader>m", "<cmd>RenderMarkdown toggle<cr>", desc = "[M]arkdown preview toggle" },
	},
	opts = {},
}

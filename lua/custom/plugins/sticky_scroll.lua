return {
	"nvim-treesitter/nvim-treesitter-context",
	event = "BufReadPost",
	opts = {
		mode = "topline",
		max_lines = 5,
		multiline_threshold = 1,
		trim_scope = "outer",
	},
}

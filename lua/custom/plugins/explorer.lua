local function toggleExplorer()
	if vim.bo.filetype == "neo-tree" then
		vim.cmd("Neotree close")
	else
		vim.cmd("Neotree reveal")
	end
end

return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		lazy = false,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		keys = {
			{ "<C-e>", toggleExplorer, mode = { "n", "t" }, desc = "File explorer" },
		},
		init = function()
			vim.api.nvim_create_autocmd("VimEnter", {
				callback = function()
					local argc = vim.fn.argc()
					local directory = argc == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 and vim.fn.argv(0)
					if argc ~= 0 and not directory then
						return
					end
					if directory then
						local directoryBuffer = vim.api.nvim_get_current_buf()
						vim.cmd.cd(directory)
						vim.cmd.enew()
						vim.api.nvim_buf_delete(directoryBuffer, { force = true })
					end
					vim.cmd("Neotree show")
				end,
			})
		end,
		opts = {
			close_if_last_window = true,
			filesystem = {
				follow_current_file = { enabled = true },
				use_libuv_file_watcher = true,
				hijack_netrw_behavior = "disabled",
			},
			window = {
				width = 35,
				mappings = {
					["<space>"] = "none",
					n = "add",
					d = "add_directory",
					D = "delete",
				},
			},
		},
	},
	{
		"antosha417/nvim-lsp-file-operations",
		dependencies = { "nvim-lua/plenary.nvim", "nvim-neo-tree/neo-tree.nvim" },
		config = function()
			require("lsp-file-operations").setup()
		end,
	},
}

local function bufferFile()
	local name = vim.api.nvim_buf_get_name(0)
	if package.loaded["codediff.core.virtual_file"] then
		local root, _, path = require("codediff.core.virtual_file").parse_url(name)
		if path then
			return vim.fs.joinpath(root, path)
		end
	end
	if vim.bo.buftype ~= "" or name == "" then
		return nil
	end
	return name
end

local function toggleExplorer()
	if vim.bo.filetype == "neo-tree" then
		return vim.cmd("Neotree close")
	end
	local file = bufferFile()
	local revealable = file and vim.uv.fs_stat(file) and vim.fs.relpath(vim.fn.getcwd(), file)
	require("neo-tree.command").execute({ action = "focus", reveal_file = revealable and file or nil })
end

local function projectPath(absolute)
	return vim.fs.relpath(vim.fn.getcwd(), absolute) or absolute
end

local function selectedTreePaths(tree, nodePath)
	local first, last = vim.fn.line("v"), vim.fn.line(".")
	local paths, seen = {}, {}
	for line = math.min(first, last), math.max(first, last) do
		local node = tree:get_node(line)
		local absolute = node and nodePath(node)
		if absolute and not seen[absolute] then
			seen[absolute] = true
			table.insert(paths, projectPath(absolute))
		end
	end
	return paths
end

local function pathsUnderCursor()
	if vim.bo.filetype == "neo-tree" then
		return selectedTreePaths(require("neo-tree.sources.manager").get_state_for_window().tree, function(node)
			return node.path
		end)
	end
	if vim.bo.filetype == "codediff-explorer" then
		local lifecycle = require("codediff.ui.lifecycle")
		local tabpage = vim.api.nvim_get_current_tabpage()
		local root = lifecycle.get_session(tabpage).git_root
		return selectedTreePaths(lifecycle.get_panel_view(tabpage).tree, function(node)
			local relative = node.data and (node.data.path or node.data.dir_path)
			return relative and vim.fs.joinpath(root, relative)
		end)
	end
	local file = bufferFile()
	return file and { projectPath(file) } or {}
end

local function copyPaths()
	local paths = pathsUnderCursor()
	if vim.fn.mode():match("^[vV\22]") then
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
	end
	if #paths == 0 then
		return vim.notify("No file path here", vim.log.levels.WARN)
	end
	vim.fn.setreg("+", table.concat(paths, "\n"))
	vim.notify(#paths == 1 and "Copied " .. paths[1] or "Copied " .. #paths .. " paths")
end

local function revealInFinder()
	local path = pathsUnderCursor()[1]
	if not path then
		return vim.notify("No file here to show in Finder", vim.log.levels.WARN)
	end
	vim.system({ "open", "-R", path }, { cwd = vim.fn.getcwd() })
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
			{ "<leader>b", "<cmd>Neotree toggle show<cr>", desc = "Show / hide file explorer" },
			{ "<M-D-c>", copyPaths, mode = { "n", "x" }, desc = "Copy path" },
			{ "<M-D-r>", revealInFinder, desc = "Reveal in Finder" },
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
				filtered_items = {
					visible = true,
					hide_dotfiles = false,
					never_show = { ".git", ".DS_Store" },
				},
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

local M = {}

local cached

local function git(args, done)
	local command = vim.list_extend({ "git", "-C", vim.fn.getcwd() }, args)
	vim.system(command, { text = true }, vim.schedule_wrap(function(result)
		done(result.code == 0 and vim.trim(result.stdout) or nil)
	end))
end

local function store(name)
	if name ~= cached then
		cached = name
		vim.cmd.redrawstatus()
	end
end

local function rebasingBranch(gitDir)
	for _, rebaseDir in ipairs({ "rebase-merge", "rebase-apply" }) do
		local headName = gitDir .. "/" .. rebaseDir .. "/head-name"
		if vim.uv.fs_stat(headName) then
			return vim.fn.readfile(headName)[1]:gsub("^refs/heads/", "")
		end
	end
end

function M.refresh()
	git({ "symbolic-ref", "--short", "-q", "HEAD" }, function(branch)
		if branch then
			return store(branch)
		end
		git({ "rev-parse", "--absolute-git-dir" }, function(gitDir)
			local rebasing = gitDir and rebasingBranch(gitDir)
			if rebasing then
				return store("rebasing " .. rebasing)
			end
			if not gitDir then
				return store(nil)
			end
			git({ "rev-parse", "--short", "HEAD" }, store)
		end)
	end)
end

function M.name()
	return cached
end

return M

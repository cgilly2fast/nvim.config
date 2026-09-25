local gitignoredButSearchable = { ".idea" }

local M = {}

function M.extra(cwd)
	cwd = cwd or vim.fn.getcwd()
	return vim.tbl_filter(function(name)
		return vim.fn.isdirectory(cwd .. "/" .. name) == 1
	end, gitignoredButSearchable)
end

function M.all(cwd)
	local extra = M.extra(cwd)
	if #extra > 0 then
		return { ".", unpack(extra) }
	end
end

function M.findCommand(cwd)
	local list = "rg --files --hidden --glob '!**/.git/*'"
	local extra = M.extra(cwd)
	if #extra == 0 then
		return { "sh", "-c", list }
	end
	return { "sh", "-c", list .. "; rg --files --hidden " .. table.concat(extra, " ") }
end

return M

local files = ${files}

${vfs}

local root = ""
local args = {...}
if #args == 1 and args[1] == '--extract' then
	extract(root, files, "", root)
else
	local env = makeEnv(root, files)
	local func, err = env.loadfile(${startup})
	if not func then error(err, 0) end
	return func(...)
end

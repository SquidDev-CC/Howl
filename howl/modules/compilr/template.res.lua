--[[
	Hideously Smashed Together by Compilr, a Hideous Smash-Stuff-Togetherer, (c) 2014 oeed
	This file REALLLLLLLY isn't suitable to be used for anything other than being executed
	To extract all the files, run: "<filename> --extract" in the Shell
]]

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

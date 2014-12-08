--- Core script used to bootstrap the howl process
-- when running in a non-compiled howl environment
-- @module Bootstrap

local howlDirectory = fs.getDir(shell.getRunningProgram())

local fileLoader = loadfile
local env = setmetatable({}, {__index = getfenv()})
env.loadlocalfile = function(path)
	local file = fileLoader(fs.combine(howlDirectory, path))
	assert(file, "Cannot load file at " .. fs.combine(howlDirectory, path))
	return setfenv(file, env)
end
env.dolocalfile = function(path) return env.loadlocalfile(path)() end

local args = {...}
xpcall(setfenv(function()
	ArgParse = dolocalfile("core/ArgParse.lua")
	Utils = dolocalfile("core/Utils.lua")
	Depends = dolocalfile("depends/Depends.lua")

	Task = dolocalfile("tasks/Task.lua")
	dolocalfile("depends/Combiner.lua")
	dolocalfile("tasks/Extensions.lua")
	HowlFile = dolocalfile("core/HowlFileLoader.lua")

	loadlocalfile("Howl.lua")(unpack(args))
end, env), function(err)
	printError(err)
	for i = 4, 15 do
		local s, msg = pcall(function() error("", i) end)
		if msg:match("_Bootstrap.lua") then break end
		print("\t", msg)
	end
end)
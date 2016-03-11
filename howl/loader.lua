--- Handles loading and creation of HowlFiles
-- @module howl.loader

local Utils = require "howl.lib.utils"
local Runner = require "howl.tasks.runner"
local fs = require "howl.platform".fs

--- Names to test when searching for Howlfiles
local Names = { "Howlfile", "Howlfile.lua" }

--- Finds the howl file
-- @treturn string The name of the howl file or nil if not found
-- @treturn string The path of the howl file or the error message if not found
local function FindHowl()
	local currentDirectory = fs.currentDir()

	while true do
		for _, file in ipairs(Names) do
			local howlFile = fs.combine(currentDirectory, file)
			if fs.exists(howlFile) and not fs.isDir(howlFile) then
				return file, currentDirectory
			end
		end

		if currentDirectory == "/" or currentDirectory == "" then
			break
		end
		currentDirectory = fs.getDir(currentDirectory)
	end


	return nil, "Cannot find HowlFile. Looking for '" .. table.concat(Names, "', '") .. "'"
end

--- Create an environment for running howl files
-- @tparam table variables A list of variables to include in the environment
-- @treturn table The created environment
local function SetupEnvironment(variables)
	local env = setmetatable(variables or {}, { __index = getfenv() })

	function env.loadfile(path)
		return setfenv(loadfile(path), env)
	end

	function env.dofile(path)
		return env.loadfile(path)()
	end

	return env
end

--- Setup tasks
-- @tparam howl.Context context The current environment
-- @tparam string howlFile location of Howlfile relative to current directory
-- @treturn Runner The task runner
local function SetupTasks(context, howlFile)
	local tasks = Runner(context)

	context.mediator:subscribe({ "ArgParse", "changed" }, function(options)
		tasks.ShowTime = options:Get "time"
		tasks.Traceback = options:Get "trace"
	end)

	-- Setup an environment
	local environment = SetupEnvironment({
		-- Core globals
		CurrentDirectory = context.root,
		Tasks = tasks,
		Options = context.arguments,
		-- Helper functions
		Verbose = context.logger/"verbose",
		Log = context.logger/"dump",
		File = function(...) return fs.combine(context.root, ...) end,
	})

	context.mediator:publish({ "HowlFile", "env" }, environment, context)

	return tasks, environment
end


--- @export
return {
	FindHowl = FindHowl,
	SetupEnvironment = SetupEnvironment,
	SetupTasks = SetupTasks,
	Names = Names,
}

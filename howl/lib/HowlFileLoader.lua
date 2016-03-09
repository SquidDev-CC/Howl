--- Handles loading and creation of HowlFiles
-- @module howl.core.HowlFile

--- Names to test when searching for Howlfiles
local Names = { "Howlfile", "Howlfile.lua" }

--- Finds the howl file
-- @treturn string The name of the howl file or nil if not found
-- @treturn string The path of the howl file or the error message if not found
local function FindHowl()
	local currentDirectory = Helpers.dir()

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

	env._G = _G
	function env.loadfile(path)
		return setfenv(loadfile(path), env)
	end

	function env.dofile(path)
		return env.loadfile(path)()
	end

	Mediator.Publish({ "HowlFile", "env" }, env)

	return env
end

--- Setup tasks
-- @tparam string currentDirectory Current directory
-- @tparam string howlFile location of Howlfile relative to current directory
-- @tparam Options options Command line options
-- @treturn Runner The task runner
local function SetupTasks(currentDirectory, howlFile, options)
	local tasks = Runner.Factory({
		CurrentDirectory = currentDirectory,
		Options = options,
	})

	Mediator.Subscribe({ "ArgParse", "changed" }, function(options)
		tasks.ShowTime = options:Get "time"
		tasks.Traceback = options:Get "trace"
	end)

	-- Setup an environment
	local environment = SetupEnvironment({
		-- Core globals
		CurrentDirectory = currentDirectory,
		Tasks = tasks,
		Options = options,
		-- Helper functions
		Verbose = Utils.Verbose,
		Log = Utils.VerboseLog,
		File = function(...) return fs.combine(currentDirectory, ...) end,
	})

	return tasks, environment
end


--- @export
return {
	FindHowl = FindHowl,
	SetupEnvironment = SetupEnvironment,
	SetupTasks = SetupTasks,
	Names = Names,
}

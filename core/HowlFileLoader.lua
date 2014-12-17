--- Handles loading and creation of HowlFiles
-- @module HowlFile

--- Finds the howl file
-- @treturn string The name of the howl file
-- @treturn string The path of the howl file
local function FindHowl()
	local currentDirectory = shell.dir()
	local howlFiles = {"Howlfile", "Howlfile.lua"}

	while true do
		for _, file in ipairs(howlFiles) do
			howlFile = fs.combine(currentDirectory, file)
			if fs.exists(howlFile) and not fs.isDir(howlFile) then
				return file, currentDirectory
			end
		end

		if currentDirectory == "/" or currentDirectory == "" then
			break
		end
		currentDirectory = fs.getDir(currentDirectory)
	end


	error("Cannot find HowlFile. Looking for '" .. table.concat(howlFiles, "', '") .. "'")
end

local hooks = {}

--- Create an environment for running howl files
-- @tparam table variables A list of variables to include in the environment
-- @treturn table The created environment
local function SetupEnvironment(variables)
	local env = setmetatable(variables or {}, { __index = getfenv()})

	env._G = _G
	function env.loadfile(path)
		local loaded = loadfile(fs.combine(env.CurrentDirectory, path))
		assert(loaded, "Cannot load file " .. tostring(path))
		return setfenv(loaded, env)
	end

	function env.dofile(path)
		return env.loadfile(path)()
	end

	for _, callback in ipairs(hooks) do
		callback(env)
	end

	return env
end

--- Setup a hook to allow additions to the environment
-- @tparam function callback The function to add..
local function EnvironmentHook(callback)
	table.insert(hooks, callback)
end

--- The current howlfile location
-- @tfield string CurrentDirectory

--- @export
return {
	FindHowl = FindHowl,
	SetupEnvironment = SetupEnvironment,
	EnvironmentHook = EnvironmentHook,
	CurrentDirectory = ""
}
--- Handles loading and creation of HowlFiles
-- @module HowlFile

--- Finds the howl file
-- @treturn string The name of the howl file or nil if not found
-- @treturn string The path of the howl file or the error message if not found
local function FindHowl()
	local currentDirectory = Helpers.dir()
	local howlFiles = { "Howlfile", "Howlfile.lua" }

	while true do
		for _, file in ipairs(howlFiles) do
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


	return nil, "Cannot find HowlFile. Looking for '" .. table.concat(howlFiles, "', '") .. "'"
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

--- The current howlfile location
-- @tfield string CurrentDirectory

--- @export
return {
	FindHowl = FindHowl,
	SetupEnvironment = SetupEnvironment
}

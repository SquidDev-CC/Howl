local function FindHowl()
	local currentDirectory = shell.dir()
	local howlFiles = {"Howl", "Howlfile", "Howlfile.lua"}

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

local function SetupEnvironment(variables)
	local env = setmetatable(variables, { __index = getfenv()})

	env._G = _G
	function env.loadfile(path)
		local loaded = loadfile(fs.combine(env.CurrentDirectory, path))
		assert(loaded)
		return setfenv(loaded, env)
	end

	function env.dofile(path)
		return env.loadfile(path)()
	end

	return env
end

return {
	FindHowl = FindHowl,
	SetupEnvironment = SetupEnvironment,
}
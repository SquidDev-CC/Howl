--- Creates a bootstrap file, which is used to run dependencies
-- @module depends.Bootstrap

local header = [=[--[[
This is a script that is used to load other files
]]
local env = setmetatable({}, {__index = getfenv()})
local function doWithResult(file)
	local func = loadfile(file)
	assert(func, "Cannot find " .. file)
	local currentEnv = setmetatable({}, {__index = env})
	setfenv(func, currentEnv)
	local result = func()
	if result ~= nil then return result end
	return currentEnv
end
local function doFile(file, ...)
	local func = loadfile(file)
	assert(func, "Cannot find " .. file)
	setfenv(func, env)(...)
end
]=]

--- Combines dependencies dynamically into one file
-- These files are loaded using loadfile rather than loaded at compile time
-- @tparam string outputFile The path of the output file
-- @see Depends.Dependencies
function Depends.Dependencies:CreateBootstrap(outputFile)
	local path = self.path

	local output = fs.open(fs.combine(HowlFile.CurrentDirectory, outputFile), "w")
	assert(output, "Could not create" .. outputFile)

	output.writeLine(header)

	local exports = {}
	for file in self:Iterate() do
		local filePath = string.format("%q", fs.combine(path, file.path))

		local moduleName = file.name
		if file.__isMain then -- If the file is a main file then execute it with the file's arguments
			output.writeLine("doFile(" .. filePath .. ", ...)")

		elseif moduleName then -- If the file has an module name then use that
			output.writeLine("env[" .. string.format("%q", moduleName) .. "] = doWithResult(" .. filePath .. ")")

		else -- We have no name so we can just execute it normally
			output.writeLine("doFile(" .. filePath .. ")")
		end
	end

	output.close()
end

--- A task creating a 'dynamic' combination of files
-- @tparam string name Name of the task
-- @tparam Depends.Dependencies dependencies The dependencies to compile
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn tasks.Runner.Runner The task runner (for chaining)
-- @see tasks.Runner.Runner
function Runner.Runner:CreateBootstrap(name, dependencies, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function()
		dependencies:CreateBootstrap(outputFile)
	end)
		:Description("Creates a 'dynamic' combination of files in '" .. outputFile .. "')")
		:Produces(outputFile)
end
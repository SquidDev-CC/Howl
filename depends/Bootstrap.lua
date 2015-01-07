--- Creates a bootstrap file, which is used to run dependencies
-- @module depends.Bootstrap
local tracebackHeader = [[
local args = {...}
xpcall(function()
	(function(...)
]]

local tracebackFooter = [[
	end)(unpack(args))
end, function(err)
	printError(err)
	for i = 3, 15 do
		local s, msg = pcall(error, "", i)
		if msg:match("xpcall") then break end
		printError("  ", msg)
	end
	error(err:match(":.+"):sub(2), 3)
end)
]]

local header = [[
local env = setmetatable({}, {__index = getfenv()})
local function doWithResult(file)
	local currentEnv = setmetatable({}, {__index = env})
	local result = setfenv(assert(loadfile(file), "Cannot find " .. file), currentEnv)()
	if result ~= nil then return result end
	return currentEnv
end
local function doFile(file, ...)
	return setfenv(assert(loadfile(file), "Cannot find " .. file), env)(...)
end
]]

--- Combines dependencies dynamically into one file
-- These files are loaded using loadfile rather than loaded at compile time
-- @tparam string outputFile The path of the output file
-- @tparam boolean traceback Include code to print the traceback
-- @see Depends.Dependencies
function Depends.Dependencies:CreateBootstrap(outputFile, traceback)
	local path = self.path

	local output = fs.open(fs.combine(HowlFile.CurrentDirectory, outputFile), "w")
	assert(output, "Could not create" .. outputFile)

	if traceback then
		output.writeLine(tracebackHeader)
	end

	output.writeLine(header)

	local exports = {}
	for file in self:Iterate() do
		local filePath = string.format("%q", fs.combine(path, file.path))

		local moduleName = file.name
		if file.__isMain then -- If the file is a main file then execute it with the file's arguments
			output.writeLine("doFile(" .. filePath .. ", ...)")

		elseif moduleName then -- If the file has an module name then use that
			output.writeLine("env[" .. string.format("%q", moduleName) .. "] = " .. (file.noWrap and "doFile" or "doWithResult") .. "(" .. filePath .. ")")

		else -- We have no name so we can just execute it normally
			output.writeLine("doFile(" .. filePath .. ")")
		end
	end

	if traceback then
		output.writeLine(tracebackFooter)
	end

	output.close()
end

--- A subclass of @{tasks.Task.Task} for bootstrappers
-- @type BootstrapTask
local BootstrapTask = setmetatable({}, {__index = Task.Task})

--- Should we include code to print the traceback
-- @tparam boolean traceback
-- @treturn BootstrapTask The current object (for chaining)
function BootstrapTask:Traceback(traceback)
	if traceback == nil then traceback = true end
	self.traceback = traceback
	return self
end


function BootstrapTask:_RunAction(...)
	return Task.Task._RunAction(self, self.traceback, ...)
end

--- A task creating a 'dynamic' combination of files
-- @tparam string name Name of the task
-- @tparam Depends.Dependencies dependencies The dependencies to compile
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn Bootstrap The created task
-- @see tasks.Runner.Runner
function Runner.Runner:CreateBootstrap(name, dependencies, outputFile, taskDepends)
	return self:InjectTask(Task.Factory(name, taskDepends, function(traceback)
		dependencies:CreateBootstrap(outputFile, traceback)
	end, BootstrapTask))
		:Description("Creates a 'dynamic' combination of files in '" .. outputFile .. "')")
		:Produces(outputFile)
end
--- Combines multiple files into one file
-- Extends @{depends.Depends.Dependencies} and @{tasks.Runner.Runner} classes
-- @module depends.Combiner

local functionLoaderName = "_W"
--[[
	If the function returns a non nil value then we use that, otherwise we
	export the environment that it ran in (and so get the globals of it)
	This probably need some work as a function but...
]]
local functionLoader = ("local function " .. functionLoaderName .. [[(f)
	local e=setmetatable({}, {__index = getfenv()})
	setfenv(f,e)
	local r=f()
	if r ~= nil then return r end
	return e
end]]):gsub("[\t ]+", " ")

--- Combines Dependencies into one file
-- @tparam string outputFile The path of the output file
-- @see Depends.Dependencies
function Depends.Dependencies:Combiner(outputFile)
	local path = self.path
	local shouldExport = self.shouldExport

	local output = fs.open(fs.combine(path, outputFile), "w")
	assert(output, "Could not create" .. outputFile)

	output.writeLine(functionLoader)

	local exports = {}
	for file in self:Iterate() do
		local fileHandle = fs.open(fs.combine(path, file.path), "r")
		assert(fileHandle, "File" .. file.path .. "does not exist")

		Utils.Verbose("Adding " .. file.path)

		local moduleName = file.name
		if file.__isMain then -- If the file is a main file then just print it
			output.writeLine(fileHandle.readAll())

		elseif moduleName then -- If the file has an module name then use that
			local line = moduleName .. '=' .. functionLoaderName .. '(function()'
			if not file.shouldExport then -- If this object shouldn't be exported then add local
				line = "local " .. line
			elseif not shouldExport then -- If we shouldn't export globally then add to the export table and mark as global
				table.insert(exports, moduleName)
				line = "local " .. line
			end

			output.writeLine(line)
			output.writeLine(fileHandle.readAll())
			output.writeLine('end)')

		else -- We have no name so we can just export it normally
			output.writeLine("do")
			output.writeLine(fileHandle.readAll())
			output.writeLine('end')
		end

		fileHandle.close()
	end

	-- Should we export any values?
	if shouldExport then
		output.writeLine("return {")
		for _, export in ipairs(exports) do
			output.writeLine("\t" .. export .. "=" .. export ..",")
		end
		output.writeLine("}")
	end
	output.close()
end

--- A task for combining stuff
-- @tparam string name Name of the task
-- @tparam depends.Depends.Dependencies dependencies The dependencies to compile
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn tasks.Runner.Runner The task runner (for chaining)
-- @see tasks.Runner.Runner
function Runner.Runner:Combine(name, dependencies, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function()
		dependencies:Combiner(outputFile)
	end)
		:Description("Combines files into '" .. outputFile .. "'")
		:Produces(outputFile)
end
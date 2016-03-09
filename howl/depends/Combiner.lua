--- Combines multiple files into one file
-- Extends @{depends.Depends.Dependencies} and @{tasks.Runner.Runner} classes
-- @module depends.Combiner

local combinerMediator = Mediator.GetChannel { "Combiner" }

local functionLoaderName = "_W"
--[[
	If the function returns a non nil value then we use that, otherwise we
	export the environment that it ran in (and so get the globals of it)
	This probably need some work as a function but...
]]
local functionLoader = ("local function " .. functionLoaderName .. [[(f)
	local e=setmetatable({}, {__index = _ENV or getfenv()})
	if setfenv then setfenv(f, e) end
	return f(e) or e
end]]):gsub("[\t\n ]+", " ")

--- Combiner options
-- @table CombinerOptions
-- @tfield boolean verify Verify source
-- @tfield boolean lineMapping Map line numbers (Requires traceback)
-- @tfield boolean traceback Print the traceback out

--- Combines Dependencies into one file
-- @tparam env env The current environment
-- @tparam string outputFile The path of the output file
-- @tparam CombinerOptions options Options for combining
-- @see Depends.Dependencies
function Depends.Dependencies:Combiner(env, outputFile, options)
	options = options or {}
	local path = self.path
	local shouldExport = self.shouldExport
	local format = Helpers.serialize

	local output = fs.open(fs.combine(env.CurrentDirectory, outputFile), "w")
	assert(output, "Could not create " .. outputFile)

	local includeChannel = combinerMediator:getChannel("include")

	local outputObj, write
	do -- Create the write object
		local writeLine = output.writeLine
		local writeChannel = combinerMediator:getChannel("write")
		local writePublish = writeChannel.publish

		write = function(contents, file)
			if writePublish(writeChannel, {}, self, file, contents, options) then
				writeLine(contents)
			end
		end

		outputObj = {
			write = write,
			path = outputFile
		}
	end

	combinerMediator:getChannel("start"):publish({}, self, outputObj, options)

	-- If header == nil or header is true then include the header
	if options.header ~= false then write(functionLoader) end

	local exports = {}
	for file in self:Iterate() do
		local filePath = file.path
		local fileHandle = fs.open(fs.combine(path, filePath), "r")
		assert(fileHandle, "File " .. filePath .. " does not exist")

		local contents = fileHandle.readAll()
		fileHandle.close()

		-- Check if it is OK to include this file
		local continue, result = includeChannel:publish({}, self, file, contents, options)
		if not continue then
			output.close()
			error(result[#result] or "Unknown error")
		end

		Utils.Verbose("Adding " .. filePath)

		local moduleName = file.name
		if file.type == "Main" then -- If the file is a main file then just print it
			write(contents, file.alias or file.path)
		elseif file.type == "Resource" then
			local line = assert(moduleName, "A name must be specified for resource " .. file.path) .. "="
			if not file.shouldExport then
				line = "local " .. line
			elseif not shouldExport then
				exports[#exports + 1] = moduleName
				line = "local " .. line
			end
			write(line .. format(contents), file.alias or file.path) -- If the file is a resource then quote it and print it
		elseif moduleName then -- If the file has an module name then use that
			-- Check if we are prevented in setting a custom environment
			local startFunc, endFunc = functionLoaderName .. '(function(_ENV, ...)', 'end)'
			if file.noWrap then
				startFunc, endFunc = '(function(...)', 'end)()'
			end

			local line = moduleName .. '=' .. startFunc
			if not file.shouldExport then -- If this object shouldn't be exported then add local
				line = "local " .. line
			elseif not shouldExport then -- If we shouldn't export globally then add to the export table and mark as global
				exports[#exports + 1] = moduleName
				line = "local " .. line
			end

			write(line)
			write(contents, moduleName)
			write(endFunc)

		else -- We have no name so we can just export it normally
			local wrap = not file.noWrap -- Don't wrap in do...end if noWrap is set

			if wrap then write("do") end
			write(contents, file.alias or file.path)
			if wrap then write('end') end
		end
	end

	-- Should we export any values?
	if #exports > 0 and #self.mainFiles == 0 then
		local exported = {}
		for _, export in ipairs(exports) do
			exported[#exported + 1] = export .. "=" .. export .. ", "
		end
		write("return {" .. table.concat(exported) .. "}")
	end

	combinerMediator:getChannel("end"):publish({}, self, outputObj, options)
	output.close()
end

--- A task for combining stuff
-- @tparam string name Name of the task
-- @tparam depends.Depends.Dependencies dependencies The dependencies to compile
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn CombinerTask The created task
-- @see tasks.Runner.Runner
function Runner.Runner:Combine(name, dependencies, outputFile, taskDepends)
	return self:InjectTask(Task.Factory(name, taskDepends, function(options, env)
		dependencies:Combiner(env, outputFile, options)
	end, Task.OptionTask))
		:Description("Combines files into '" .. outputFile .. "'")
		:Produces(outputFile)
		:Requires(dependencies:Paths())
end

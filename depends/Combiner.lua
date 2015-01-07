--- Combines multiple files into one file
-- Extends @{depends.Depends.Dependencies} and @{tasks.Runner.Runner} classes
-- @module depends.Combiner

local find = string.find

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


local lineMapper = {
	header = [[
		-- Maps
		local lineToModule = setmetatable({{lineToModule}}, {
			__index = function(t, k)
				if k > 1 then return t[k-1] end
			end
		})
		local moduleStarts = {{modulestarts}}
		local programEnd = {{currentLine}}

		-- Stores the current file, safer than shell.getRunningProgram()
		local currentFile = pcall(error, "", 2):match("[^:]")
	]]
	updateError = [[
		-- Something is really broken if we can't find a filename
		-- If we can't find a line number than we must have `pcall:` or `xpcall`
		-- This means, we shouldn't have an error, so we must be debugging somewhere
		if not filename or not line then return end

		-- If we are in the current file then we should map to the old modules
		if filename == currentFile then

			-- If this line is after the program end then
			-- something is broken, and so we just roll with it
			if line >= programEnd then return end

			-- convert to module lines
			filename = lineToModule[line] or "<?>"
			line = line - moduleStarts[filename] or -1
		end
	]]
}

local finalizer = {
	header = [[
		local finalizer = function() {{finalizer}} end
	]],
	parseTrace = [[
		local ok, finaliserError = pcall(finalizer, message, traceback)

		if not ok then
			printError("Finalizer Error: ", finaliserError)
		end
	]]
}

local traceback = ([[
end

local args = {...}
local currentTerm = term.current()
local ok, returns = xpcall(
	function() return {__program(unpack(args))} end,
	function(message)
		local error, pcall, printError, tostring,setmetatable = error, pcall, printError, tostring, setmetatable
		{{header}}

		local messageMeta = {
			__tostring = function(self)
				local msg = self.filename or "<?>"
				if self.line then msg = msg .. ":" .. tostring(self.line) end
				if self.message then msg = msg .. ":" .. tostring(self.message) end
			end
		end}
		local function updateError(err)
			local filename, line, message = err:match("([^:]):(%d+):(.+)")
			{{updateError}}
			return setmetatable({filename, line, message}, messageMeta)
		end

		-- Reset terminal
		term.redirect(currentTerm)

		-- Build a traceback
		local topError = updateError(message) or message
		local traceback = {topError}
		for i = 3, 3 + 18 do
			local _, err = pcall(error, "", i)
			err = updateError(err)
			if not err then break end
			traceback[#traceback + 1] = err
		end

		{{parseTrace}}

		printError(tostring(topError))
		print("Raw Stack Trace:")
		for i =2, #traceback do
			print("  ", tostring(traceback[i]))
		end
	end
)

if ok then
	return unpack(returns)
end
]]):gsub("[\t ]+", " ")

--- Counts the number of lines in a string
-- @tparam string contents The string to count
-- @treturn int The line count
local function countLines(contents)
	local position, start, newPosition = 1, 1, 1
	local lineCount = 1
	local length = #contents
	while position < length do
		start, newPosition = find(contents, '\n', position, true);
		if not start then break end
		lineCount = lineCount + 1
		position = newPosition + 1
	end
	return lineCount
end

--- Verify a source file
-- @tparam string contents The lua string to verify
-- @throws When source is not valid
local function verifySource(contents, path)
	local success, err = loadstring(contents)
	if not success then
		local msg = "Could not load " .. (path and ("file " .. path) or "string")
		if err ~= "nil" then msg = msg  .. ":\n" .. err end
		error(msg)
	end
end


--- Combiner options
-- @table CombinerOptions
-- @tfield boolean verify Verify source
-- @tfield boolean lineMapping Map line numbers (Requires traceback)
-- @tfield boolean traceback Print the traceback out

--- Combines Dependencies into one file
-- @tparam string outputFile The path of the output file
-- @tparam boolean header Include the header function
-- @tparam CombinerOptions options Options for combining
-- @see Depends.Dependencies
function Depends.Dependencies:Combiner(outputFile, header, options)
	local path = self.path
	local shouldExport = self.shouldExport
	local lineMapping = options.lineMapping
	local loadstring = loadstring

	local line, oldLine = 1, 1
	local lineToModule, moduleStarts = {}, {}

	local function setLines(mod, n1, n2)
		if not n1 and not n2 then return end

		if moduleStarts[mod] then
			moduleStarts[mod] = math.min(n1, moduleStarts[mod])
		else
			moduleStarts[mod] = n1
		end

		local min
		if n1 and not n2 then
			min = n1
		elseif not n1 and n2 then
			min = n2
		elseif n1 and n2 then
			min = math.min(n1, n2)
		end

		lineToModule[min] = mod
	end

	local output = fs.open(fs.combine(HowlFile.CurrentDirectory, outputFile), "w")
	assert(output, "Could not create " .. outputFile)

	local function writeLine(contents, name)
		output.writeLine(contents)
		if lineMapping then
			oldLine = line
			line = line + countLines(contents)
			setLines(name or outputFile, oldLine + 1, line - 1)
		end
	end

	-- If header == nil or header is true then include the header
	writeLine("local __program = function(...)")

	if header ~= false then writeLine(functionLoader, "file") end


	local exports = {}
	for file in self:Iterate() do
		local filePath = file.path
		local fileHandle = fs.open(fs.combine(path, filePath), "r")
		assert(fileHandle, "File " .. filePath .. " does not exist")

		local contents = fileHandle.readAll()
		fileHandle.close()

		if verify then verifySource(contents, filePath) end

		local beginline
		Utils.Verbose("Adding " .. filePath)

		local moduleName = file.name
		if file.__isMain then -- If the file is a main file then just print it
			writeLine(contents, file.alias or file.path)

		elseif moduleName then -- If the file has an module name then use that
			-- Check if we are prevented in setting a custom environment
			local startFunc, endFunc = functionLoaderName .. '(function()', 'end)'
			if file.noWrap then
				startFunc, endFunc = '(function()', 'end)()'
			end

			local line = moduleName .. '=' .. startFunc
			if not file.shouldExport then -- If this object shouldn't be exported then add local
				line = "local " .. line
			elseif not shouldExport then -- If we shouldn't export globally then add to the export table and mark as global
				exports[#exports + 1] = moduleName
				line = "local " .. line
			end

			writeLine(line)
			writeLine(contents, moduleName)
			writeLine(endFunc)

		else -- We have no name so we can just export it normally
			local noWrap = file.noWrap -- Don't wrap in do...end if noWrap is set

			if not noWrap then writeLine("do") end
			writeLine(contents, file.alias or file.path)
			if not noWrap then writeLine('end') end
		end
	end

	local finalizerContents
	if self.finalizer then
		local path = fs.combine(path, self.finalizer.path)
		local finalizer = assert(fs.open(path, "r"), "Finalizer " .. path .. " does not exist")

		finalizerContents = r.readAll()
		finalizer.close()

		if #finalizerContents == 0 then
			finalizerContents = nil
		elseif verify then
			verifySource(finalizerContents, path)
		end
	end

	-- Should we export any values?
	if shouldExport then
		local exported = {}
		for _, export in ipairs(exports) do
			exported[#exported+1] = export .. "=" .. export ..", "
		end
		writeLine("return {" .. table.concat(exported) .. "}")
	end

	output.writeLine(lineMapper)
	output.close()
end

--- A subclass of @{tasks.Task.Task} for combiners
-- @type CombinerTask
local CombinerTask = setmetatable({}, {__index = Task.Task})

--- Should files be verified on execution
-- @tparam boolean verify
-- @treturn CombinerTask The current object (for chaining)
function CombinerTask:Verify(verify)
	if verify == nil then verify = true end
	self.verify = verify
	return self
end

function CombinerTask:_RunAction(...)
	return Task.Task._RunAction(self, self.verify, ...)
end

--- A task for combining stuff
-- @tparam string name Name of the task
-- @tparam depends.Depends.Dependencies dependencies The dependencies to compile
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn CombinerTask The created task
-- @see tasks.Runner.Runner
function Runner.Runner:Combine(name, dependencies, outputFile, taskDepends)
	return self:InjectTask(Task.Factory(name, taskDepends, function(verify)
		dependencies:Combiner(outputFile, true, verify)
	end, CombinerTask))
		:Description("Combines files into '" .. outputFile .. "'")
		:Produces(outputFile)
end

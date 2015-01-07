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
-- @tparam boolean header Include the header function
-- @tparam boolean verify Verify the source files before loading
-- @see Depends.Dependencies
function Depends.Dependencies:Combiner(outputFile, header, verify)
	local line = 2
	local oldLine = 2
	local linetomodule = {}
	local modulestarts = {}
	
	local function getLines(str)
		local x, a, b = 1;
		local c = 1
		while x < string.len(str) do
			a, b = string.find(str, '.-\n', x);
			if not a then
				break;
			else
				c = c +1
			end;
			x = b + 1;
		end
		return c
	end
	local function setLines(mod, n1, n2)
		if not n1 and not n2 then return end
		
		if modulestarts[mod] then
			modulestarts[mod] = math.min(n1, modulestarts[mod])
		else
			modulestarts[mod] = n1
		end
		
		local min
		if n1 and not n2 then
			min = n1
		elseif not n1 and n2 then
			min = n2
		elseif n1 and n2 then
			min = math.min(n1, n2)
		end
		
		linetomodule[min] = mod
	end
	
	local path = self.path
	local shouldExport = self.shouldExport
	local loadstring = loadstring
	
	local output = fs.open(fs.combine(HowlFile.CurrentDirectory, outputFile), "w")
	assert(output, "Could not create" .. outputFile)
	
	function writeLine(txt, mod)
		output.writeLine(txt)
		oldLine = line
		line = line + getLines(txt)
		setLines(mod or "Unknown", oldLine +1, line -1)
	end

	-- If header == nil or header is true then include the header
	output.writeLine("local __program = function(...)")
	
	if header ~= false then writeLine(functionLoader, "file") end
	
	
	local exports = {}
	for file in self:Iterate() do
		local filePath = file.path
		local fileHandle = fs.open(fs.combine(path, filePath), "r")
		assert(fileHandle, "File " .. filePath .. " does not exist")

		local contents = fileHandle.readAll()
		fileHandle.close()

		if verify then
			local success, err = loadstring(contents)
			if not success then
				Utils.VerboseLog({contents, success, err, {loadstring("HELLO")}})
				local msg = "Could not load file " .. filePath
				if err ~= "nil" then msg = msg  .. ":\n" .. err end
				error(msg)
			end
		end
		
		local beginline = 
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
				exports[#exports + 1] =  moduleName
				line = "local " .. line
			end

			writeLine(line, "file")
			writeLine(contents, moduleName)
			writeLine(endFunc, "file")

		else -- We have no name so we can just export it normally
			local noWrap = file.noWrap -- Don't wrap in do...end if noWrap is set

			if noWrap then writeLine("do", "file") end
			writeLine(contents, file.alias or file.path)
			if noWrap then writeLine("end", "file") end
		end
	end
	
	local finalizertxt = ""
	if self.finalizer then
		local r = fs.open(fs.combine(path, self.finalizer.path), "r")
		assert(r, "Could not open "..fs.combine(path, self.finalizer.path))
		finalizertxt = r.readAll() or ""
	end
	-- Should we export any values?
	if shouldExport then
		writeLine("return {", "file")
		for _, export in ipairs(exports) do
			writeLine("\t" .. export .. "=" .. export ..",", "file")
		end
		writeLine("}", "file")
	end
	output.writeLine(
[[
end
local __finalizer = function() ]]..finalizertxt..[[ end 
local __linetomodule = setmetatable(]]..textutils.serialize(linetomodule)..[[, {__index = function(t, k) if k > 1 then return t[k-1] end end})
local __modulestarts = ]]..textutils.serialize(modulestarts)..[[ 
local __programend = ]]..line..[[ 
local firstfilename = nil
local function __updateerr(__err)
	local __t = string.find(__err, ":")
	if not __t then return __err end
	local __filename = __err:sub(1, __t -1)
	if not firstfilename then
		firstfilename = __err:sub(1, __t-1)
	end
	if __filename ~= firstfilename then
		return __err
	end
	local __t2 = string.find(string.sub(__err, __t +1, -1), ":")
	if not __t2 then return __err end
	local __errline = tonumber(string.sub(__err, __t +1, __t + __t2 -1))
	
	if __errline then
		-- convert to module lines
		if __errline >= __programend then
			return nil
		end
		local __modname = __linetomodule[__errline] or "unknown"
		local __modline = __errline - __modulestarts[__modname] or -1
		return __modname..":"..__modline..":"..tostring(__err:sub(__t + __t2 +1, -1))
		
	end
end
local __varargs = {...}
local __returns = {}
local __current = term.current()
local __ok, __err = xpcall(function() __returns = {__program(unpack(__varargs))} end, 
function(msg) pcall(function() (function(__msg)
	__msg = "  "..(__updateerr(__msg) or "")
	for i = 8, 7 + 18 do
		local _, err = pcall(function() error("", i) end)
		err = __updateerr(err)
		if not err then break end
		__msg = __msg .. "\n  " .. err
	end

	err = __msg
	local finmsg
	local ok, _err = pcall(function() finmsg = __finalizer() end)
	term.redirect(__current)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.red)
	term.clear()
	term.setCursorPos(1, 1)
	if not ok then
		print("Finalizer Error: ", _err)
	end
	if finmsg then
		print(finmsg)
	end
	print("Raw Stack Trace: \n", err)
	return err
end)(msg) end) end)
if __ok then
	return unpack(__returns)
end
]])
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
-- @treturn tasks.Runner.Runner The task runner (for chaining)
-- @see tasks.Runner.Runner
function Runner.Runner:Combine(name, dependencies, outputFile, taskDepends)
	return self:InjectTask(Task.Factory(name, taskDepends, function(verify)
		dependencies:Combiner(outputFile, true, verify)
	end, CombinerTask))
		:Description("Combines files into '" .. outputFile .. "'")
		:Produces(outputFile)
end
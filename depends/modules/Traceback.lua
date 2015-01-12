--- Handles finalizers and tracebacks
-- @module depends.modules.Traceback

local find = string.find

--- LineMapper template
local lineMapper = {
	header = [[
		-- Maps
		local lineToModule = setmetatable({{lineToModule}}, {
			__index = function(t, k)
				if k > 1 then return t[k-1] end
			end
		})
		local moduleStarts = {{moduleStarts}}
		local programEnd = {{lastLine}}

		-- Stores the current file, safer than shell.getRunningProgram()
		local _, currentFile = pcall(error, "", 2)
		currentFile = currentFile:match("[^:]+")
	]],
	updateError = [[
		-- If we are in the current file then we should map to the old modules
		if filename == currentFile then

			-- If this line is after the program end then
			-- something is broken, and so we just roll with it
			if line > programEnd then return end

			-- convert to module lines
			filename = lineToModule[line] or "<?>"
			local newLine = moduleStarts[filename]
			if newLine then
				line = line - newLine + 1
			else
				line = -1
			end
		end
	]]
}

--- Finalizer template
local finalizer = {
	header = [[
		local finalizer = function(message, traceback) {{finalizer}} end
	]],
	parseTrace = [[
		local ok, finaliserError = pcall(finalizer, message, traceback)

		if not ok then
			printError("Finalizer Error: ", finaliserError)
		end
	]]
}

--- Traceback template
local traceback = ([[
end
-- The main program executor
	local args = {...}
	local currentTerm = term.current()
	local ok, returns = xpcall(
		function() return {__program(unpack(args))} end,
		function(message)
			local _, err = pcall(function()
			local error, pcall, printError, tostring,setmetatable = error, pcall, printError, tostring, setmetatable
			{{header}}

			local messageMeta = {
				__tostring = function(self)
					local msg = self[1] or "<?>"
					if self[2] then msg = msg .. ":" .. tostring(self[2]) end
					if self[3] and self[3] ~= " " then msg = msg .. ":" .. tostring(self[3]) end
					return msg
				end
			}
			local function updateError(err)
				local filename, line, message = err:match("([^:]+):(%d+):?(.*)")
				-- Something is really broken if we can't find a filename
				-- If we can't find a line number than we must have `pcall:` or `xpcall`
				-- This means, we shouldn't have an error, so we must be debugging somewhere
				if not filename or not line then return end
				line = tonumber(line)
				{{updateError}}
				return setmetatable({filename, line, message}, messageMeta)
			end

			-- Reset terminal
			term.redirect(currentTerm)

			-- Build a traceback
			local topError = updateError(message) or message
			local traceback = {topError}
			for i = 6, 6 + 18 do
				local _, err = pcall(error, "", i)
				err = updateError(err)
				if not err then break end
				traceback[#traceback + 1] = err
			end

			{{parseTrace}}

			printError(tostring(topError))
			if #traceback > 1 then
				printError("Raw Stack Trace:")
				for i = 2, #traceback do
					printError("  ", tostring(traceback[i]))
				end
			end
			end)
			if not _ then printError(err) end
		end
	)

	if ok then
		return unpack(returns)
	end
]])

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

--- Create a template, replacing {{...}} with replacers
-- @tparam string contents The string to count
-- @treturn int The line count
local function replaceTemplate(source, replacers)
	return source:gsub("{{(.-)}}", function(whole)
		return replacers[whole] or ""
	end)
end

Mediator.Subscribe({"Combiner", "start"}, function(self, outputFile, options)
	if self.finalizer then
		options.traceback = true
	end

	if options.lineMapping then
		options.oldLine = 0
		options.line = 0
		options.lineToModule = {}
		options.moduleStarts = {}
	end

	if options.traceback then
		outputFile.write("local __program = function(...)")
	end
end)

local min = math.min
Mediator.Subscribe({"Combiner", "write"}, function(self, name, contents, options)
	if options.lineMapping then
		name = name or "file"

		local oldLine = options.line
		options.oldLine = oldLine

		local line = oldLine countLines(contents)
		options.line = line

		oldLine = oldLine + 1
		line = line - 1

		local moduleStarts, lineToModule = options.moduleStarts, options.lineToModule

		local starts = moduleStarts[name]
		if starts then
			moduleStarts[name] = min(oldLine, starts)
		else
			moduleStarts[name] = oldLine
		end

		lineToModule[min(oldLine, line)] = name
	end
end)

Mediator.Subscribe({"Combiner", "end"}, function(self, outputFile, options)
	if options.traceback then
		local tracebackIncludes = {}
		local replacers = {}

		-- Handle finalizer
		if self.finalizer then
			local finalizerPath = self.finalizer.path
			local path = fs.combine(self.path, finalizerPath)
			local finalizerFile = assert(fs.open(path, "r"), "Finalizer " .. path .. " does not exist")

			finalizerContents = finalizerFile.readAll()
			finalizerFile.close()

			if #finalizerContents == 0 then
				finalizerContents = nil
			else
				Mediator.Publish({"Combiner", "include"}, self, finalizerPath, finalizerContents, options)
			end

			-- Register template
			if finalizerContents then
				tracebackIncludes[#tracebackIncludes + 1] = finalizer
				replacers.finalizer = finalizerContents
			end
		end

		-- Handle line mapper
		if options.lineMapping then
			tracebackIncludes[#tracebackIncludes + 1] = lineMapper

			local dump = textutils.serialize
			replacers.lineToModule = dump(lineToModule)
			replacers.moduleStarts = dump(moduleStarts)
			replacers.lastLine = options.line
		end

		-- And handle replacing
		toReplace = {}
		for _, template in ipairs(tracebackIncludes) do
			for part, contents in pairs(template) do
				local current = toReplace[part]
				if current then
					current = current .. "\n"
				else
					current = ""
				end
				toReplace[part] = current .. contents
			end
		end

		-- Replace templates and write it
		outputFile.write(replaceTemplate(replaceTemplate(traceback, toReplace), replacers))
	end
end)

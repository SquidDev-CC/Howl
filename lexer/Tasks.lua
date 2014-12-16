--- Tasks for the lexer
-- @module lexer.Tasks

local function MinifyFile(inputFile, outputFile)
	local cd = HowlFile.CurrentDirectory
	local input = fs.open(fs.combine(cd, inputFile), "r")
	local contents = input.readAll()
	input.close()

	contents = Rebuild.Minify(Parse.ParseLua(Parse.LexLua(contents)))

	local result = fs.open(fs.combine(cd, outputFile), "w")
	result.write(contents)
	result.close()
end


--- A task that minifies a source file
-- @tparam string name Name of the task
-- @tparam string inputFile The input file
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn Runner.Runner The task runner (for chaining)
-- @see tasks.Runner.Runner
function Runner.Runner:Minify(name, inputFile, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function()
		MinifyFile(inputFile, outputFile)
	end)
		:Description("Minifies '" .. fs.getName(inputFile) .. "'' into '" .. fs.getName(outputFile) .. "'")
		:Requires(inputFile)
		:Produces(outputFile)
end

--- A task that minifies to a pattern instead
-- @tparam string name Name of the task
-- @tparam string inputPattern The pattern to read in
-- @tparam string outputPattern The pattern to produce
-- @treturn tasks.Runner.Runner The task runner (for chaining)
function Runner.Runner:MinifyAll(name, inputPattern, outputPattern)
	name = name or "_minify"
	return self:AddTask(name, {}, MinifyFile)
		:Description("Minifies files")
		:Maps(inputPattern or "wild:*.lua", outputPattern or "wild:*.min.lua")
end
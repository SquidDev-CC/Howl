--- Tasks for the lexer
-- @module lexer.Tasks

local function MinifyFile(inputFile, outputFile)
	local input = fs.open(inputFile, "r")
	local contents = input.readAll()
	input.close()

	local contents = Rebuild.Minify(Parse.ParseLua(Parse.LexLua(contents)))

	local result = fs.open(outputFile, "w")
	result.write(contents)
	result.close()
end


--- A task that minifies a source file
-- @tparam string name Name of the task
-- @tparam string inputFile The input file
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{Task.Task|tasks} this task requires
-- @treturn Runner.Runner The task runner (for chaining)
-- @see Runner.Runner
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
-- @treturn Runner.Runner The task runner (for chaining)
function Runner.Runner:MinifyAll(name, inputPattern, outputPattern)
	name = name or "_minify"
	return self:AddTask(name, {}, MinifyFile)
		:Description("Minifies files")
		:Maps(inputPattern or "wild:*.lua", outputPattern or "wild:*.min.lua")
end
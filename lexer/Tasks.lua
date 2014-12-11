--- Tasks for the lexer
-- @module lexer.Tasks

--- A task that minifies a source file
-- @tparam string name Name of the task
-- @tparam string inputFile The input file
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{Task.Task|tasks} this task requires
-- @treturn Task.TaskRunner The task runner (for chaining)
-- @see Task.TaskRunner
function Task.TaskRunner:Minify(name, inputFile, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function()
		local input = fs.open(inputFile, "r")
		local contents = input.readAll()
		input.close()

		local contents = Rebuild.Minify(Parse.ParseLua(Parse.LexLua(contents)))

		local result = fs.open(outputFile, "w")
		result.write(contents)
		result.close()
	end):Description("Minifies '" .. fs.getName(inputFile) .. "'' into '" .. fs.getName(outputFile) .. "'")
end
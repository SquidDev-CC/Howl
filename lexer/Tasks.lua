--- Tasks for the lexer
-- @module lexer.Tasks
local minifyFile = Rebuild.MinifyFile
local minifyDiscard = function(self, i, o) return minifyFile(i, o) end

--- A task that minifies a source file
-- @tparam string name Name of the task
-- @tparam string inputFile The input file
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn Runner.Runner The task runner (for chaining)
-- @see tasks.Runner.Runner
function Runner.Runner:Minify(name, inputFile, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function()
		if type(inputFile) == "table" then
			assert(type(outputFile) == "table", "Output File must be a table too")

			local lenIn = #inputFile
			assert(lenIn == #outputFile, "Tables must be the same length")

			for i = 1, lenIn do
				minifyFile(inputFile[i], outputFile[i])
			end
		else
			minifyFile(inputFile, outputFile)
		end
	end)
		:Description("Minifies '" .. fs.getName(inputFile) .. "' into '" .. fs.getName(outputFile) .. "'")
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
	return self:AddTask(name, {}, minifyDiscard)
		:Description("Minifies files")
		:Maps(inputPattern or "wild:*.lua", outputPattern or "wild:*.min.lua")
end

Mediator.Subscribe({"HowlFile", "env"}, function(env)
	env.Minify = minifyFile
end)

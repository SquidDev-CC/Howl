--- Tasks for the lexer
-- @module howl.lexer.tasks
local Rebuild = require "howl.lexer.rebuild"
local Runner = require "howl.tasks.runner"
local Mediator = require "howl.lib.mediator"

local minifyFile = Rebuild.MinifyFile
local minifyDiscard = function(self, env, i, o)
	return minifyFile(env.root, i, o)
end

--- A task that minifies a source file
-- @tparam string name Name of the task
-- @tparam string inputFile The input file
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.task.Task|tasks} this task requires
-- @treturn howl.tasks.Task The created task
-- @see tasks.Runner.Runner
function Runner:Minify(name, inputFile, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function(task, env)
		if type(inputFile) == "table" then
			assert(type(outputFile) == "table", "Output File must be a table too")

			local lenIn = #inputFile
			assert(lenIn == #outputFile, "Tables must be the same length")

			for i = 1, lenIn do
				minifyFile(env.root, inputFile[i], outputFile[i])
			end
		else
			minifyFile(env.root, inputFile, outputFile)
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
-- @treturn howl.tasks.Task The created task
function Runner:MinifyAll(name, inputPattern, outputPattern)
	name = name or "_minify"
	return self:AddTask(name, {}, minifyDiscard)
		:Description("Minifies files")
		:Maps(inputPattern or "wild:*.lua", outputPattern or "wild:*.min.lua")
end

Mediator:subscribe({ "HowlFile", "env" }, function(env)
	env.Minify = minifyFile
end)

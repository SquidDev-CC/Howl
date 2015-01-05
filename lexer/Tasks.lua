--- Tasks for the lexer
-- @module lexer.Tasks

local push, pop = os.queueEvent, coroutine.yield
local function MinifyFile(inputFile, outputFile)
	local cd = HowlFile.CurrentDirectory
	local input = fs.open(fs.combine(cd, inputFile), "r")
	local contents = input.readAll()
	input.close()

	local lex = Parse.LexLua(contents)
	push("sleep") pop("sleep") -- Minifying often takes too long

	lex = Parse.ParseLua(lex)
	push("sleep") pop("sleep")

	contents = Rebuild.Minify(lex)

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
		if type(inputFile) == "table" then
			assert(type(outputFile) == "table", "Output File must be a table too")

			local lenIn = #inputFile
			assert(lenIn == #outputFile, "Tables must be the same length")

			for i = 1, lenIn do
				MinifyFile(inputFile[i], outputFile[i])
				push("sleep") pop("sleep")
			end
		else
			MinifyFile(inputFile, outputFile)
		end
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
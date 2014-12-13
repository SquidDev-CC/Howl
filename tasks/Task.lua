--- The main task class
-- @module tasks.Task

local matches = {
	["^"] = "%^",
	["$"] = "%$",
	["("] = "%(",
	[")"] = "%)",
	["%"] = "%%",
	["."] = "%.",
	["["] = "%[",
	["]"] = "%]",
	--["*"] = "%*";
	["+"] = "%+",
	["-"] = "%-",
	["?"] = "%?",
	["\0"] = "%z",
}

--- Parse a series of patterns
local function ParsePattern(from, to)
	local beginning = from:sub(1, 5)
	if beginning == "ptrn:" or beginning == "wild:" then
		assert(beginning == to:sub(1, 5), string.format("Both '%s' and '%s' have the same prefix", from, to))

		local fromEnd = from:sub(6)
		local toEnd = to:sub(6)
		if beginning == "wild:" then
			-- Escape the pattern and replace wildcards with (.*) capture
			toEnd = ((toEnd:gsub(".", matches)):gsub("(%*)", "(.*)"))

			local counter = 0
			-- Escape the pattern and then replace wildcards with the results of the capture %1, %2, etc...
			fromEnd = ((fromEnd:gsub(".", matches)):gsub("(%*)", function()
				counter = counter + 1
				return "%" .. counter
			end))
		end

		return {Type = "Pattern", From = fromEnd, To = toEnd}
	else
		return {Type = "Normal", From = from, To = to}
	end
end

--- A single task: actions, dependencies and metadata
-- @type Task
local Task = {}

--- Define what this task depends on
-- @tparam string|table name Name/list of dependencies
-- @treturn Task The current object (allows chaining)
function Task:Depends(name)
	if type(name) == "table" then
		local dependencies = self.dependencies
		for _, file in ipairs(name) do
			table.insert(dependencies, name)
		end
	else
		table.insert(self.dependencies, name)
	end

	return self
end

--- Sets a file this task requires
-- @tparam string|table file The path of the file
-- @treturn Task The current object (allows chaining)
function Task:Requires(file)
	if type(file) == "table" then
		local requires = self.requires
		for _, file in ipairs(file) do
			table.insert(requires, file)
		end
	else
		table.insert(self.requires, file)
	end
	return self
end

--- Sets a file this task produces
-- @tparam string|table file The path of the file
-- @treturn Task The current object (allows chaining)
function Task:Produces(file)
	if type(file) == "table" then
		local produces = self.produces
		for _, file in ipairs(file) do
			table.insert(produces, file)
		end
	else
		table.insert(self.produces, file)
	end
	return self
end

--- Sets a file mapping
-- @tparam string from The file to map form
-- @tparam string to The file to map to
-- @treturn Task The current object (allows chaining)
function Task:Maps(from, to)
	table.insert(self.maps, ParsePattern(from, to))
	return self
end

--- Set the action for this task
-- @tparam function action The action to run
-- @treturn Task The current object (allows chaining)
function Task:Action(action)
	self.action = action
	return self
end

--- Set the description for this task
-- @tparam string text The description of the task
-- @treturn Task The current object (allows chaining)
function Task:Description(text)
	self.description = text
	return self
end

--- Execute the task
-- @tparam Context.Context context The task context
-- @param ... The arguments to pass to task
-- @tparam boolean Success
function Task:Run(context, ...)
	for _, depends in ipairs(self.dependencies) do
		if not context:Run(depends) then
			return false
		end
	end

	for _, file in ipairs(self.requires) do
		if not context:DoRequire(file) then
			return false
		end
	end

	for _, file in ipairs(self.produces) do
		context.filesProduced[file] = true
	end

	-- Technically we don't need to specify an action
	if self.action then
		local args = {...}
		local description = ""

		-- Get a list of arguments
		if #args > 0 then
			newArgs = {}
			for _, arg in ipairs(args) do
				table.insert(newArgs, tostring(arg))
			end
			description = " (" .. table.concat(newArgs, ", ") .. ")"
		end
		Utils.PrintColor(colors.cyan, "Running " .. self.name .. description)

		local oldTime = os.time()
		local s, err = true, nil
		if context.Traceback then
			xpcall(function() self.action(unpack(args)) end, function(msg)
				for i = 5, 15 do
					local _, err = pcall(function() error("", i) end)
					if msg:match("Howlfile") then break end
					msg = msg .. "\n  " .. err
				end

				err = msg
				s = false
			end)
		else
			s, err = pcall(self.action, ...)
		end

		if s then
			Utils.PrintSuccess(self.name .. ": Success")
		else
			Utils.PrintError(self.name .. ": Failure\n" .. err)
		end

		if context.ShowTime then
			Utils.Print("\t", "Took " .. os.time() - oldTime .. "s")
		end

		return s
	end

	return true
end

--- Create a task
-- @tparam string name The name of the task
-- @tparam table dependencies A list of tasks this task requires
-- @tparam function action The action to run
-- @tparam table prototype The base class of the Task
-- @treturn Task The created task
local function Factory(name, dependencies, action, prototype)
	-- Check calling with no dependencies
	if type(dependencies) == "function" then
		action = dependencies
		dependencies = {}
	end

	return setmetatable({
		name = name,       -- The name of the function
		action = action,   -- The action to call
		dependencies = dependencies or {}, -- Task dependencies
		description = nil, -- Description of the task
		maps = {},         -- Reads and produces list
		requires = {},     -- Files this task requires
		produces = {},     -- Files this task produces
	}, {__index = prototype or Task})
end

--- @export
return {
	Factory = Factory,
	Task = Task,
}
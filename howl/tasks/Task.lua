--- The main task class
-- @classmod howl.tasks.Task

local utils = require "howl.lib.utils"
local colored = require "howl.lib.colored"
local class = require "howl.lib.middleclass"

--- Convert a pattern
local function ParsePattern(from, to)
	local fromParsed = utils.parsePattern(from, true)
	local toParsed = utils.parsePattern(to)

	local newType = fromParsed.Type
	assert(newType == toParsed.Type, "Both from and to must be the same type " .. newType .. " and " .. fromParsed.Type)

	return { Type = newType, From = fromParsed.Text, To = toParsed.Text }
end

local Task = class("howl.tasks.Task")

--- Define what this task depends on
-- @tparam string|table name Name/list of dependencies
-- @treturn Task The current object (allows chaining)
function Task:Depends(name)
	if type(name) == "table" then
		local dependencies = self.dependencies
		for _, task in ipairs(name) do
			table.insert(dependencies, task)
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

--- Run the action with no bells or whistles
function Task:_RunAction(env, ...)
	return self.action(self, env, ...)
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
		local args = { ... }
		local description = ""

		-- Get a list of arguments
		if #args > 0 then
			local newArgs = {}
			for _, arg in ipairs(args) do
				table.insert(newArgs, tostring(arg))
			end
			description = " (" .. table.concat(newArgs, ", ") .. ")"
		end
		colored.printColor("cyan", "Running " .. self.name .. description)

		local oldTime = os.clock()
		local s, err = true, nil
		if context.Traceback then
			xpcall(function() self:_RunAction(context.env, unpack(args)) end, function(msg)
				for i = 5, 15 do
					local _, err = pcall(function() error("", i) end)
					if msg:match("Howlfile") then break end
					msg = msg .. "\n  " .. err
				end

				err = msg
				s = false
			end)
		else
			s, err = pcall(self._RunAction, self, context.env, ...)
		end

		if s then
			context.env.logger:success(self.name .. ": Success")
		else
			context.env.logger:error(self.name .. ": Failure\n" .. err)
		end

		if context.ShowTime then
			print(" ", "Took " .. os.clock() - oldTime .. "s")
		end

		return s
	end

	return true
end

--- Create a task
-- @tparam string name The name of the task
-- @tparam table dependencies A list of tasks this task requires
-- @tparam function action The action to run
-- @treturn Task The created task
function Task:initialize(name, dependencies, action)
	-- Check calling with no dependencies
	if type(dependencies) == "function" then
		action = dependencies
		dependencies = {}
	end

	self.name = name -- The name of the function
	self.action = action -- The action to call
	self.dependencies = dependencies or {} -- Task dependencies
	self.description = nil -- Description of the task
	self.maps = {} -- Reads and produces list
	self.requires = {} -- Files this task requires
	self.produces = {} -- Files this task produces
end

return Task

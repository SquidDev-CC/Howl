--- The main task class
-- @classmod howl.tasks.Task

local assert = require "howl.lib.assert"
local class = require "howl.class"
local colored = require "howl.lib.colored"
local mixin = require "howl.class.mixin"
local os = require "howl.platform".os
local utils = require "howl.lib.utils"

local insert = table.insert

--- Convert a pattern
local function parsePattern(from, to)
	local fromParsed = utils.parsePattern(from, true)
	local toParsed = utils.parsePattern(to)

	local newType = fromParsed.Type
	assert(newType == toParsed.Type, "Both from and to must be the same type " .. newType .. " and " .. fromParsed.Type)

	return { Type = newType, From = fromParsed.Text, To = toParsed.Text }
end

local Task = class("howl.tasks.Task")
	:include(mixin.configurable)
	:include(mixin.optionGroup)
	:addOptions { "description" }

--- Create a task
-- @tparam string name The name of the task
-- @tparam table dependencies A list of tasks this task requires
-- @tparam function action The action to run
-- @treturn Task The created task
function Task:initialize(name, dependencies, action)
	assert.argType(name, "string", "Task", 1)

	-- Check calling with no dependencies
	if type(dependencies) == "function" then
		action = dependencies
		dependencies = {}
	end

	self.options = {}
	self.name = name -- The name of the function
	self.action = action -- The action to call
	self.dependencies = {} -- Task dependencies
	self.maps = {} -- Reads and produces list
	self.produces = {} -- Files this task produces

	if dependencies then self:depends(dependencies) end
end

function Task.static:addDependency(class, name)
	local function apply(self, ...)
		if select('#', ...) == 1 and type(...) == "table" and (#(...) > 0 or next(...) == nil) then
			local first = ...
			for i = 1, #first do
				insert(self.dependencies, class(self, first[i]))
			end
		else
			insert(self.dependencies, class(self, ...))
		end

		return self
	end

	self[name] = apply
	self[name:gsub("^%l", string.upper)] = apply

	return self
end

function Task:setup(context, runner) end

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
	table.insert(self.maps, parsePattern(from, to))
	return self
end

--- Set the action for this task
-- @tparam function action The action to run
-- @treturn Task The current object (allows chaining)
function Task:Action(action)
	self.action = action
	return self
end

--- Run the action with no bells or whistles
function Task:runAction(context, ...)
	if self.action then
		return self.action(self, context, ...)
	else
		return true
	end
end

--- Execute the task
-- @tparam Context.Context context The task context
-- @param ... The arguments to pass to task
-- @tparam boolean Success
function Task:Run(context, ...)
	local shouldRun = false
	if #self.dependencies == 0 then
		shouldRun = true
	else
		for _, depends in ipairs(self.dependencies) do
			if depends:resolve(context.env, context) then
				shouldRun = true
			end
		end
	end

	if not shouldRun then return false end

	for _, file in ipairs(self.produces) do
		context.filesProduced[file] = true
	end

	-- Technically we don't need to specify an action
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
	context.env.logger:info("Running %s", self.name .. description)

	local oldTime = os.clock()
	local s, err = true, nil
	if context.Traceback then
		xpcall(function() self:runAction(context.env, unpack(args)) end, function(msg)
			for i = 5, 15 do
				local _, err = pcall(function() error("", i) end)
				if msg:match("Howlfile") then break end
				msg = msg .. "\n  " .. err
			end

			err = msg
			s = false
		end)
	else
		s, err = pcall(self.runAction, self, context.env, ...)
	end

	if s then
		context.env.logger:success("%s finished", self.name)
		if self.description=="Minify a file" then
			--For minify tasks, show reduction percent
			local oldFile = io:open(self.options.input,"r")
			local newFile = io:open(self.options.output,"r")
			local oldSize = oldFile:seek("end")
			local newSize = newFile:seek("end")
			oldFile:close()
			newFile:close()
			local percentDecreased = (oldSize-newSize)/oldSize
			percentDecreased = percentDecreased * 100
			context.env.logger:info("%s%% decrease in file size",string.format("%.0f",percentDecreased))
		end
	else
		context.env.logger:error("%s: %s", self.name, err or "no message")
		error("Error running tasks", 0)
	end

	if context.ShowTime then
		print(" ", "Took " .. os.clock() - oldTime .. "s")
	end

	return true
end

return Task

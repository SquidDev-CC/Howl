--- Handles tasks and dependencies
-- @classmod howl.tasks.Runner

local class = require "howl.class"
local colored = require "howl.lib.colored"
local Context = require "howl.tasks.Context"
local mixin = require "howl.class.mixin"
local os = require "howl.platform".os
local Task = require "howl.tasks.Task"

--- Handles a collection of tasks and running them
-- @type Runner
local Runner = class("howl.tasks.Runner"):include(mixin.sealed)

--- Create a @{Runner} object
-- @tparam env env The current environment
-- @treturn Runner The created runner object
function Runner:initialize(env)
	self.tasks = {}
	self.default = nil
	self.env = env
end

function Runner:setup()
	for _, task in pairs(self.tasks) do
		task:setup(self.env, self)
	end

	if self.env.logger.hasError then return false end

	for _, task in pairs(self.tasks) do
		for _, dependency in ipairs(task.dependencies) do
			dependency:setup(self.env, self)
		end
	end

	if self.env.logger.hasError then return false end
	return true
end

--- Create a task
-- @tparam string name The name of the task to create
-- @treturn function A builder for tasks
function Runner:Task(name)
	return function(dependencies, action) return self:addTask(name, dependencies, action) end
end

--- Add a task to the collection
-- @tparam string name The name of the task to add
-- @tparam table dependencies A list of tasks this task requires
-- @tparam function action The action to run
-- @treturn Task The created task
function Runner:addTask(name, dependencies, action)
	return self:injectTask(Task(name, dependencies, action))
end

--- Add a Task object to the collection
-- @tparam Task task The task to insert
-- @tparam string name The name of the task (optional)
-- @treturn Task The current task
function Runner:injectTask(task, name)
	self.tasks[name or task.name] = task
	return task
end

--- Set the default task
-- @tparam ?|string|function task The task to run or the name of the task
-- @treturn Runner The current object for chaining
function Runner:Default(task)
	local defaultTask
	if task == nil then
		self.default = nil
	elseif type(task) == "string" then
		self.default = self.tasks[task]
		if not self.default then
			error("Cannot find task " .. task)
		end
	else
		self.default = Task("<default>", {}, task)
	end

	return self
end

--- Run a task, and all its dependencies
-- @tparam string name Name of the task to run
-- @treturn Runner The current object for chaining
function Runner:Run(name)
	return self:RunMany({ name })
end

--- Run a task, and all its dependencies
-- @tparam table names Names of the tasks to run
-- @return The result of the last task
function Runner:RunMany(names)
	local oldTime = os.clock()
	local value = true

	local context = Context(self)
	if #names == 0 then
		context:Start()
	else
		for _, name in ipairs(names) do
			value = context:Start(name)
			if not value then break end
		end
	end

	if context.ShowTime then
		colored.printColor("orange", "Took " .. os.clock() - oldTime .. "s in total")
	end

	return value
end

return Runner

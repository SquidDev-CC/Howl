--- @module Task

local Task = {}

--- Define what this task depends on
-- @tparam string/table Name/list of dependencies
-- @treturn Task The current object (allows chaining)
function Task:Depends(name)
	if type(name) == "table" then
		for _, file in ipairs(name) do
			self:Depends(name)
		end
	else
		table.insert(self.dependencies, name)
	end

	return self
end

--- Set the action for this task
-- @tparam function func The action to run
-- @treturn Task The current object (allows chaining)
function Task:Action(action)
	assert(action and type(action) == "function", "action must be a function")
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
--- Create a task
-- @tparam table dependencies A list of tasks this task requires
-- @tparam function The action to run
-- @treturn Task The created task
local function TaskFactory(dependencies, action)
	-- Check calling with no dependencies
	if type(dependencies) == "function" then
		action = dependencies
		dependencies = {}
	end

	return setmetatable({action = action, dependencies = dependencies, description = nil}, {__index = Task})
end

local TaskRunner = {}

--- Create a task
-- @tparam string name The name of the task to create
-- @treturn function A builder for tasks
function TaskRunner:Task(name)
	return function(dependencies, action) return self:AddTask(name, dependencies, action) end
end

--- Add a task to the collection
-- @tparam string name The name of the task to add
-- @tparam table dependencies A list of tasks this task requires
-- @tparam function The action to run
-- @treturn Task The created task
function TaskRunner:AddTask(name, dependencies, action)
	local task = TaskFactory(dependencies, action)
	self.tasks[name] = task
	return task
end

--- Set the default task
-- @tparam ?|string|function The task to run or the name of the task
-- @treturn TaskRunner The current object for chaining
function TaskRunner:Default(task)
	local defaultTask
	if task == nil then
		self.default = nil
	elseif type(task) == "string" then
		self.default  = self.tasks[task]
		if not self.default  then
			error("Cannot find task " .. task)
		end
	else
		self.default = TaskFactory({}, task)
	end

	return self
end

--- Sets whether tasks should be timedthe time each task took?
-- @tparam bool showTime Time tasks?
-- @treturn TaskRunner The current task object
function TaskRunner:ShowTime(showTime)
	self.showTime = showTime
	return self
end

--- Run a task, and all its dependencies
-- @tparam string name Name of the task to run
-- @tparam table arguments A list of arguments to pass to the task
-- @tparam table context List of already run tasks
function TaskRunner:Run(name, context)
	context = context or {}
	table.insert(context, name)
	local currentTask
	if name then
		currentTask = self.tasks[name]
	else
		currentTask = self.default
		name = "<default>"
	end

	local showTime = self.showTime

	if not currentTask then
		Utils.PrintError("Cannot find a task called " .. name)
		return false
	end

	for _, dep in ipairs(currentTask.dependencies or {}) do
		if not context[dep] then
			if not self:Run(dep, context) then
				return false
			end
		end
	end

	local oldTime = os.time()
	Utils.PrintColor(colors.cyan, "Running " .. name)
	assert(currentTask.action, "Action cannot be nil")
	local s, err = pcall(function() currentTask.action() end)
	if s then
		Utils.PrintSuccess(name .. ": Success")
	else
		Utils.PrintError(name .. ": Failure\n" .. err)
	end

	if showTime then
		Utils.Print("\t", "Took " .. os.time() - oldTime .. "s")
	end

	return s
end

return {
	Task = Task,
	TaskRunner = TaskRunner,
	Tasks = function()
		return setmetatable({tasks = {}, default = nil}, {__index = TaskRunner})
	end,
}
--- Handles tasks and dependencies
-- @module tasks.Runner

--- Handles a collection of tasks and running them
-- @type Runner
local Runner = {}

--- Create a task
-- @tparam string name The name of the task to create
-- @treturn function A builder for tasks
function Runner:Task(name)
	return function(dependencies, action) return self:AddTask(name, dependencies, action) end
end

--- Add a task to the collection
-- @tparam string name The name of the task to add
-- @tparam table dependencies A list of tasks this task requires
-- @tparam function action The action to run
-- @treturn Task The created task
function Runner:AddTask(name, dependencies, action)
	return self:InjectTask(Task.Factory(name, dependencies, action))
end

--- Add a Task object to the collection
-- @tparam Task task The task to insert
-- @tparam string name The name of the task (optional)
-- @treturn Task The current task
function Runner:InjectTask(task, name)
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
		self.default  = self.tasks[task]
		if not self.default  then
			error("Cannot find task " .. task)
		end
	else
		self.default = Task.Factory("<default>", {}, task)
	end

	return self
end

--- Run a task, and all its dependencies
-- @tparam string name Name of the task to run
function Runner:Run(name)
	return Context.Factory(self):Start(name)
end

--- Create a @{Runner} object
-- @treturn Runner The created runner object
local function Factory()
	return setmetatable({tasks = {}, default = nil}, {__index = Runner})
end

--- @export
return {
	Factory = Factory,
	Runner = Runner
}
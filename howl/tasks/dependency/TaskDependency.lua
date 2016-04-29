--- An dependency on a task
-- @classmod howl.tasks.dependency.TaskDependency

local assert = require "howl.lib.assert"
local Task = require "howl.tasks.Task"
local Dependency = require "howl.tasks.dependency.Dependency"

local TaskDependency = Dependency:subclass("howl.tasks.dependency.TaskDependency")

--- Create a new task dependency
function TaskDependency:initialize(task, name)
	Dependency.initialize(self, task)

	assert.argType(name, "string", "initialize", 1)
	self.name = name
end

function TaskDependency:setup(context, runner)
	if not runner.tasks[self.name] then
		context.logger:error("Task '%s': cannot resolve dependency '%s'", self.task.name, self.name)
	end
end

function TaskDependency:resolve(context, runner)
	return runner:run(self.name)
end

local TaskExtensions = {}

return {
	apply = function()
		Task:addDependency(TaskDependency, "depends")
	end,

	TaskDependency = TaskDependency,
}

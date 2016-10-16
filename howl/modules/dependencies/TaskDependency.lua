--- Allows depending on a task.
-- @module howl.modules.dependencies.TaskDependency

local assert = require "howl.lib.assert"
local Task = require "howl.tasks.Task"
local Dependency = require "howl.tasks.Dependency"

local TaskDependency = Dependency:subclass("howl.modules.dependencies.TaskDependency")

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

return {
	name = "task dependency",
	description = "Allows depending on a task.",

	apply = function()
		Task:addDependency(TaskDependency, "depends")
	end,

	TaskDependency = TaskDependency,
}

--- An dependency on a file
-- @classmod howl.tasks.dependency.FileDependency

local assert = require "howl.lib.assert"
local Task = require "howl.tasks.Task"
local Dependency = require "howl.tasks.dependency.Dependency"

local FileDependency = Dependency:subclass("howl.tasks.dependency.FileDependency")

--- Create a new task dependency
function FileDependency:initialize(task, path)
	Dependency.initialize(self, task)

	assert.argType(path, "string", "initialize", 1)
	self.path = path
end

function FileDependency:setup(context, runner)
	-- TODO: Check that this can be resolved
end

function FileDependency:resolve(context, runner)
	return runner:DoRequire(self.path)
end

local TaskExtensions = {}

return {
	apply = function()
		Task:addDependency(FileDependency, "requires")
	end,

	FileDependency = FileDependency,
}

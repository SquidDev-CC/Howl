--- Allows depending on a file.
-- @module howl.modules.dependencies.FileDependency

local assert = require "howl.lib.assert"
local Task = require "howl.tasks.Task"
local Dependency = require "howl.tasks.Dependency"

local FileDependency = Dependency:subclass("howl.modules.dependencies.FileDependency")

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

return {
	name = "file dependency",
	description = "Allows depending on a file.",

	apply = function()
		Task:addDependency(FileDependency, "requires")
	end,

	FileDependency = FileDependency,
}

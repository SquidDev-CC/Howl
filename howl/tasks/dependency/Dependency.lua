--- An abstract class dependency
-- @classmod howl.tasks.dependency.Dependency

local class = require "howl.class"

local Dependency = class("howl.tasks.dependency.Dependency")

--- Create a new dependency
function Dependency:initialize(task)
	if self.class == Dependency then
		error("Cannot create instance of abstract class " .. tostring(Dependency), 2)
	end

	self.task = task
end

--- Setup the dependency, checking if it cannot be resolved
function Dependency:setup(context, runner)
	error("setup has not been overridden in " .. self.class, 2)
end

--- Execute the dependency
-- @treturn boolean If the task was run
function Dependency:resolve(context, runner)
	error("resolve has not been overridden in " .. self.class, 2)
end

return Dependency

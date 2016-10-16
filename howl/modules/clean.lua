--- Deletes all specified files
-- @module howl.modules.clean

local mixin = require "howl.class.mixin"
local fs = require "howl.platform".fs

local Task = require "howl.tasks.Task"
local Runner = require "howl.tasks.Runner"
local Source = require "howl.files.Source"

local CleanTask = Task:subclass("howl.modules.clean.CleanTask")
	:include(mixin.configurable)
	:include(mixin.filterable)
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))

function CleanTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.root = context.root
	self.sources = Source()
	self:exclude { ".git", ".svn", ".gitignore" }

	self:description "Deletes all files matching a pattern"
end

function CleanTask:configure(item)
	self.sources:configure(item)
end

function CleanTask:setup(context, runner)
	Task.setup(self, context, runner)

	local root = self.sources
	if root.allowEmpty and #root.includes == 0 then
		-- Include the build directory if nothing is set
		root:include(fs.combine(context.out, "*"))
	end
end

function CleanTask:RunAction(context)
	for _, file in ipairs(self.sources:gatherFiles(self.root, true)) do
		context.logger:verbose("Deleting " .. file.path)
		fs.delete(file.path)
	end
end

local CleanExtensions = {}

--- A task for cleaning a directory
-- Extends the @{howl.tasks.Runner} class
-- @tparam string name Name of the task
-- @tparam string directory The directory to clean
-- @tparam table taskDepends A list of tasks this task requires
-- @treturn howl.tasks.Task The created task
function CleanExtensions:clean(name, taskDepends)
	return self:InjectTask(CleanTask(self.env, name or "clean", taskDepends))
end

local function apply()
	Runner:include(CleanExtensions)
end

return {
	name = "clean",
	description = "Deletes all specified files.",
	apply = apply,

	CleanTask = CleanTask,
}

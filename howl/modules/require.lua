--- A task that combines files that can be loaded using `require`.

local assert = require "howl.lib.assert"
local mixin = require "howl.class.mixin"

local Sources = require "howl.files.Sources"
local OptionTask = require "howl.tasks.OptionTask"
local Runner = require "howl.tasks.Runner"

local RequireTask = OptionTask:subclass("howl.modules.requrie.RequireTask")
	:include(mixin.configurable)
	:include(mixin.filterable)
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))

function RequireTask:initialize(context, name, output, dependencies)
	OptionTask.initialize(self, name, dependencies, nil, { "link", "include", "exclude" })

	assert.argType(output, "string", "RequireTask", 3)
	self.sources = Sources(context.root)
	self.output = output

	self:exclude { ".git", ".svn", ".gitignore", context.out }
end

function RequireTask:configure(item)
	OptionTask.configure(self, item)
	self.sources:configure(item)
end

function RequireTask:RunAction(context)
	context.logger:dump(self.sources:getFiles())
end

local RequireExtensions = { }

function RequireExtensions:asRequire(name, outputFile, taskDepends)
	return self:InjectTask(RequireTask(self.env, name, outputFile, taskDepends))
		:Description("Packages files together to allow require")
		:Produces(outputFile)
end

local function apply()
	-- Well obviously we'd just do
	Runner:include(RequireExtensions)
end

return {
	name = "require",
	description = "A task that combines files that can be loaded using `require`.",
	apply = apply,

	RequireTask = RequireTask,
}

--- A task to combine multiple files into one which are then executed within a virtual file system.
-- @module howl.modules.tasks.Pack

local assert = require "howl.lib.assert"
local dump = require "howl.lib.dump"
local fs = require "howl.platform".fs
local mixin = require "howl.class.mixin"
local rebuild = require "howl.lexer.rebuild"

local CopySource = require "howl.files.CopySource"
local Runner = require "howl.tasks.Runner"
local Task = require "howl.tasks.Task"

local formatTemplate = require "howl.lib.utils".formatTemplate

local template = require "howl.modules.tasks.pack.template"
local vfs = require "howl.modules.tasks.pack.vfs"

local PackTask = Task:subclass("howl.modules.tasks.pack.PackTask")
	:include(mixin.filterable)
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))
	:addOptions { "minify", "startup", "output" }

function PackTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.root = context.root
	self.sources = CopySource()
	self.sources:modify(function(file)
		local contents = file.contents
		if self.options.minify and loadstring(contents) then
			return rebuild.minifyString(contents)
		end
	end)

	self:exclude { ".git", ".svn", ".gitignore", context.out }

	self:description("Combines multiple files using Pack")
end

function PackTask:configure(item)
	Task.configure(self, item)
	self.sources:configure(item)
end

-- TODO: Add a custom "ouput" mixin
function PackTask:output(value)
	assert.argType(value, "string", "output", 1)
	if self.options.output then error("Cannot set output multiple times") end

	self.options.output = value
	self:Produces(value)
end

function PackTask:setup(context, runner)
	Task.setup(self, context, runner)

	if not self.options.startup then
		context.logger:error("Task '%s': No startup file", self.name)
	end
	self:requires(self.options.startup)

	if not self.options.output then
		context.logger:error("Task '%s': No output file", self.name)
 	end
end

function PackTask:runAction(context)
	local files = self.sources:gatherFiles(self.root)
	local startup = self.options.startup
	local output = self.options.output
	local minify = self.options.minify

	local resultFiles = {}
	for _, file in pairs(files) do
		context.logger:verbose("Including " .. file.relative)
		resultFiles[file.name] = file.contents
	end

	local result = formatTemplate(template, {
		files = dump.serialise(resultFiles),
		startup = ("%q"):format(startup),
		vfs = vfs,
	})

	if minify then
		result = rebuild.minifyString(result)
	end

	fs.write(fs.combine(context.root, output), result)
end


local PackExtensions = { }

function PackExtensions:pack(name, taskDepends)
	return self:injectTask(PackTask(self.env, name, taskDepends))
end

local function apply()
	Runner:include(PackExtensions)
end

return {
	name = "pack task",
	description = "A task to combine multiple files into one which are then executed within a virtual file system.",
	apply = apply,

	PackTask = PackTask,
}

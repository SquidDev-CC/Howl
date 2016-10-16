--- Adds various tasks to minify files.
-- @module howl.modules.tasks.minify

local assert = require "howl.lib.assert"
local rebuild = require "howl.lexer.rebuild"

local Runner = require "howl.tasks.Runner"
local Task = require "howl.tasks.Task"

local minifyFile = rebuild.minifyFile
local minifyDiscard = function(self, env, i, o)
	return minifyFile(env.root, i, o)
end

local MinifyTask = Task:subclass("howl.modules.minify.tasks.MinifyTask")
	:addOptions { "input", "output" }

function MinifyTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self:description "Minify a file"
end

function MinifyTask:input(value)
	assert.argType(value, "string", "input", 1)
	if self.options.input then error("Cannot set input multiple times") end

	self.options.input = value
	self:requires(value)
end

function MinifyTask:output(value)
	assert.argType(value, "string", "output", 1)
	if self.options.output then error("Cannot set output multiple times") end

	self.options.output = value
	self:Produces(value)
end

function MinifyTask:setup(context, runner)
	Task.setup(self, context, runner)

	if not self.options.input then
		context.logger:error("Task '%s': No input file specified", self.name)
	end

	if not self.options.output then
		context.logger:error("Task '%s': No output file specified", self.name)
	end
end

function MinifyTask:runAction(context)
	minifyFile(context.root, self.options.input, self.options.output)
end

local MinifyExtensions = {}

function MinifyExtensions:minify(name, taskDepends)
	return self:injectTask(MinifyTask(self.env, name, taskDepends))
end

--- A task that minifies to a pattern instead
-- @tparam string name Name of the task
-- @tparam string inputPattern The pattern to read in
-- @tparam string outputPattern The pattern to produce
-- @treturn howl.tasks.Task The created task
function MinifyExtensions:addMinifier(name, inputPattern, outputPattern)
	name = name or "_minify"
	return self:addTask(name, {}, minifyDiscard)
		:Description("Minifies files")
		:Maps(inputPattern or "wild:*.lua", outputPattern or "wild:*.min.lua")
end

local function apply()
	Runner:include(MinifyExtensions)
end

local function setup(context)
	context.mediator:subscribe({ "HowlFile", "env" }, function(env)
		env.minify = minifyFile
	end)
end

return {
	name = "minify",
	description = "Adds various tasks to minify files.",
	apply = apply,
	setup = setup,
}

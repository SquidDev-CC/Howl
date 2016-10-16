--- [Compilr](https://github.com/oeed/Compilr) by Oeed ported to Howl by SquidDev
-- Combines files and emulates the fs API
-- @module howl.modules.compilr

local assert = require "howl.lib.assert"
local dump = require "howl.lib.dump"
local fs = require "howl.platform".fs
local mixin = require "howl.class.mixin"
local rebuild = require "howl.lexer.rebuild"

local Buffer = require "howl.lib.Buffer"
local CopySource = require "howl.files.CopySource"
local Runner = require "howl.tasks.Runner"
local Task = require "howl.tasks.Task"

local formatTemplate = require "howl.lib.utils".formatTemplate

local template = require "howl.modules.compilr.template"

local CompilrTask = Task:subclass("howl.modules.compilr.CompilrTask")
	:include(mixin.filterable)
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))
	:addOptions { "minify", "startup", "output" }

function CompilrTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.root = context.root
	self.sources = CopySource()

	self:exclude { ".git", ".svn", ".gitignore", context.out }

	self:description("Combines multiple files using Compilr")
end

function CompilrTask:configure(item)
	Task.configure(self, item)
	self.sources:configure(item)
end

-- TODO: Add a custom "ouput" mixin
function CompilrTask:output(value)
	assert.argType(value, "string", "output", 1)
	if self.options.output then error("Cannot set output multiple times") end

	self.options.output = value
	self:Produces(value)
end

function CompilrTask:setup(context, runner)
	Task.setup(self, context, runner)

	if not self.options.startup then
		context.logger:error("Task '%s': No startup file", self.name)
	end
	self:requires(self.options.startup)

	if not self.options.output then
		context.logger:error("Task '%s': No output file", self.name)
 	end
end

function CompilrTask:RunAction(context)
	local files = self.sources:gatherFiles(self.root)
	local startup = self.options.startup
	local output = self.options.output
	local minify = self.options.minify

	local resultFiles = {}
	for _, file in pairs(files) do
		context.logger:verbose("Including " .. file.relative)

		local contents = file.contents

		if minify and loadstring(contents) then -- This might contain non-lua files, ensure it doesn't
			contents = rebuild.MinifyString(contents)
		end

		local root = resultFiles
		local nodes = { file.name:match((file.name:gsub("[^/]+/?", "([^/]+)/?"))) }
		nodes[#nodes] = nil
		for _, node in pairs(nodes) do
			local nRoot = root[node]
			if not nRoot then
				nRoot = {}
				root[node] = nRoot
			end
			root = nRoot
		end

		root[fs.getName(file.name)] = contents
	end

	local result = formatTemplate(template, {
		files = dump.serialise(resultFiles),
		startup = ("%q"):format(startup)
	})

	if minify then
		result = rebuild.MinifyString(result)
	end

	fs.write(fs.combine(context.root, output), result)
end


local CompilrExtensions = { }

function CompilrExtensions:compilr(name, taskDepends)
	return self:InjectTask(CompilrTask(self.env, name, taskDepends))
end

local function apply()
	Runner:include(CompilrExtensions)
end

return {
	name = "compilr",
	description = "Combines multiple files using Compilr",
	apply = apply,

	CompilrTask = CompilrTask,
}


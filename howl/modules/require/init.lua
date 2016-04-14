--- A task that combines files that can be loaded using `require`.

local assert = require "howl.lib.assert"
local fs = require "howl.platform".fs
local mixin = require "howl.class.mixin"

local Buffer = require "howl.lib.Buffer"
local Task = require "howl.tasks.Task"
local Runner = require "howl.tasks.Runner"
local Sources = require "howl.files.Sources"

local header = require "howl.modules.require.header"
local envSetup = "local env = setmetatable({ require = require }, { __index = getfenv() })\n"

local function toModule(file)
	return file:gsub("%.lua$", ""):gsub("/", "."):gsub("^(.*)%.init$", "%1")
end

local RequireTask = Task:subclass("howl.modules.require.RequireTask")
	:include(mixin.configurable)
	:include(mixin.filterable)
	:include(mixin.options { "link", "startup", "output", "api" })
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))

function RequireTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.options = {}
	self.sources = Sources(context.root)

	self:exclude { ".git", ".svn", ".gitignore", context.out }
end

function RequireTask:configure(item)
	self:_configureOptions(item)
	self.sources:configure(item)
end

function RequireTask:output(value)
	assert.argType(value, "string", "output", 1)
	if self.options.output then error("Cannot set output multiple times") end

	self.options.output = value
	self:Produces(value)
end

function RequireTask:validate()
	if not self.options.startup then error("No startup file specified for " .. self.name) end
	if not self.options.output then error("No output file specified for " .. self.name) end
end

function RequireTask:RunAction(context)
	self:validate()

	local files = self.sources:getFiles()
	local startup = self.options.startup
	local output = self.options.output
	local link = self.options.link

	local result = Buffer()
	result:append(header):append("\n")

	if link then result:append(envSetup) end

	for _, file in pairs(files) do
		context.logger:verbose("Including " .. file.relative)
		result:append("preload[\"" .. toModule(file.name) .. "\"] = ")
		if link then
			assert(fs.exists(file.path), "Cannot find " .. file.relative)
			result:append("setfenv(assert(loadfile(\"" .. file.path .. "\")), env)\n")
		else
			local contents = fs.read(file.path)
			result:append("function(...)\n" .. contents .. "\nend\n")
		end
	end

	if self.options.api then
		result:append("if shell then\n")
	end
	result:append("return preload[\"" .. toModule(startup) .. "\"](...)\n")
	if self.options.api then
		result:append("else\n")
		result:append("return { require = require, preload = preload }\n")
		result:append("end\n")
	end

	fs.write(fs.combine(context.root, output), result:toString())
end

local RequireExtensions = { }

function RequireExtensions:asRequire(name, taskDepends)
	return self:InjectTask(RequireTask(self.env, name, taskDepends))
		:Description("Packages files together to allow require")
end

local function apply()
	Runner:include(RequireExtensions)
end

return {
	name = "require",
	description = "Combines files that can be loaded using `require`.",
	apply = apply,

	RequireTask = RequireTask,
}

--- A task that combines files that can be loaded using `require`.
-- @module howl.modules.tasks.require

local assert = require "howl.lib.assert"
local fs = require "howl.platform".fs
local mixin = require "howl.class.mixin"

local Buffer = require "howl.lib.Buffer"
local CopySource = require "howl.files.CopySource"
local Runner = require "howl.tasks.Runner"
local Task = require "howl.tasks.Task"

local header = require "howl.modules.tasks.require.header"
local envSetup = "local env = setmetatable({ require = require }, { __index = getfenv() })\n"

local function toModule(file)
	if file:find("%.lua$") then
		return file:gsub("%.lua$", ""):gsub("/", "."):gsub("^(.*)%.init$", "%1")
	end
end

local function handleRes(file)
	if file.relative:find("%.res%.") then
		file.name = file.name:gsub("%.res%.", ".")
		return ("return %q"):format(file.contents)
	end
end

local RequireTask = Task:subclass("howl.modules.require.RequireTask")
	:include(mixin.filterable)
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))
	:addOptions { "link", "startup", "output", "api" }

function RequireTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.sources = CopySource()
	self.sources:rename(function(file) return toModule(file.name) end)
	self.sources:modify(handleRes)

	self:exclude { ".git", ".svn", ".gitignore", context.out }

	self:description("Packages files together to allow require")
end

function RequireTask:configure(item)
	Task.configure(self, item)
	self.sources:configure(item)
end

function RequireTask:output(value)
	assert.argType(value, "string", "output", 1)
	if self.options.output then error("Cannot set output multiple times") end

	self.options.output = value
	self:Produces(value)
end

function RequireTask:setup(context, runner)
	Task.setup(self, context, runner)
	if not self.options.startup then
		context.logger:error("Task '%s': No startup file", self.name)
	end
	self:requires(self.options.startup)

	if not self.options.output then
		context.logger:error("Task '%s': No output file", self.name)
 	end
end

function RequireTask:runAction(context)
	local files = self.sources:gatherFiles(context.root)
	local startup = self.options.startup
	local output = self.options.output
	local link = self.options.link

	local result = Buffer()
	result:append(header):append("\n")

	if link then result:append(envSetup) end

	for _, file in pairs(files) do
		context.logger:verbose("Including " .. file.relative)
		result:append("preload[\"" .. file.name .. "\"] = ")
		if link then
			assert(fs.exists(file.path), "Cannot find " .. file.relative)
			result:append("setfenv(assert(loadfile(\"" .. file.path .. "\")), env)\n")
		else
			result:append("function(...)\n" .. file.contents .. "\nend\n")
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

function RequireExtensions:require(name, taskDepends)
	return self:injectTask(RequireTask(self.env, name, taskDepends))
end

local function apply()
	Runner:include(RequireExtensions)
end

return {
	name = "require task",
	description = "A task that combines files that can be loaded using `require`.",
	apply = apply,

	RequireTask = RequireTask,
}

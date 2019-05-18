--- A task that uploads files to a Gist.
-- @module howl.modules.tasks.gist

local assert = require "howl.lib.assert"
local mixin = require "howl.class.mixin"
local settings = require "howl.lib.settings"
local json = require "howl.lib.json"
local platform = require "howl.platform"

local http = platform.http

local Buffer = require "howl.lib.Buffer"
local Task = require "howl.tasks.Task"
local Runner = require "howl.tasks.Runner"
local CopySource = require "howl.files.CopySource"

local GistTask = Task:subclass("howl.modules.tasks.gist.GistTask")
	:include(mixin.filterable)
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))
	:addOptions { "gist", "summary" }

function GistTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.root = context.root
	self.sources = CopySource()
	self:exclude { ".git", ".svn", ".gitignore" }

	self:description "Uploads files to a gist"
end

function GistTask:configure(item)
	Task.configure(self, context, runner)
	self.sources:configure(item)
end

function GistTask:setup(context, runner)
	Task.setup(self, context, runner)
	if not self.options.gist then
		context.logger:error("Task '%s': No gist ID specified", self.name)
	end
end

function GistTask:runAction(context)
	if not settings.githubKey then
		context.logger:error("Task '%s': No GitHub API key specified. Goto https://github.com/settings/tokens/new to create one.", self.name)
		return false
	end

	local files = self.sources:gatherFiles(self.root)
	local gist = self.options.gist
	local token = settings.githubKey

	local out = {}

	for _, file in pairs(files) do
		context.logger:verbose("Including " .. file.relative)
		out[file.name] = { content = file.contents }
	end

	local url = "https://api.github.com/gists/" .. gist .. "?access_token=" .. token
	local headers = { Accept = "application/vnd.github.v3+json", ["X-HTTP-Method-Override"] = "PATCH" }
	local data = json.encodePretty({ files = out, description = self.options.summary })

	local ok, handle, message = http.request(url, data, headers)
	if not ok then
		if handle then
			context.logger:error(handle.readAll())
		end

		error(message, 0)
	end
end

local GistExtensions = { }

function GistExtensions:gist(name, taskDepends)
	return self:injectTask(GistTask(self.env, name, taskDepends))
end

local function apply()
	Runner:include(GistExtensions)
end

return {
	name = "gist task",
	description = "A task that uploads files to a Gist.",
	apply = apply,

	GistTask = GistTask,
}

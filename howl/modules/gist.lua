--- A task that combines files that can be loaded using `require`.

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

local GistTask = Task:subclass("howl.modules.gist.GistTask")
	:include(mixin.configurable)
	:include(mixin.filterable)
	:include(mixin.options { "gist", "summary" })
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))

function GistTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.options = {}
	self.root = context.root
	self.sources = CopySource()
	self:exclude { ".git", ".svn", ".gitignore" }

	self:Description "Uploads files to a gist"
end

function GistTask:configure(item)
	self:_configureOptions(item)
	self.sources:configure(item)
end

function GistTask:setup(context, runner)
	if not self.options.gist then
		context.logger:error("Task '%s': No gist ID specified", self.name)
	end
	if not settings.githubKey then
		context.logger:error("Task '%s': No GitHub API key specified. Goto https://github.com/settings/tokens/new to create one.", self.name)
	end
end

function GistTask:RunAction(context)
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
			printError(handle.readAll())
		end

		error(result, 0)
	end
end

local GistExtensions = { }

function GistExtensions:gist(name, taskDepends)
	return self:InjectTask(GistTask(self.env, name, taskDepends))
end

local function apply()
	Runner:include(GistExtensions)
end

return {
	name = "gist",
	description = "Uploads files to a gist.",
	apply = apply,

	GistTask = GistTask,
}

--- A package provider that installs gists.
-- @module howl.modules.packages.gist

local class = require "howl.class"
local json = require "howl.lib.json"
local platform = require "howl.platform"

local Manager = require "howl.packages.Manager"
local Package = require "howl.packages.Package"

local GistPackage = Package:subclass("howl.modules.packages.gist.GistPackage")
	:addOptions { "id" }

--- Setup the dependency, checking if it cannot be resolved
function GistPackage:setup(context, runner)
	if not self.options.id then
		context.logger:error("Gist has no ID")
	end
end

function GistPackage:getName()
	return self.options.id
end

function GistPackage:files(previous)
	if previous then
		local files = {}
		for k, _ in pairs(previous.files) do
			files[k] = platform.fs.combine(self.installDir, k)
		end
		return files
	else
		return {}
	end
end

function GistPackage:require(context, previous, refresh)
	local id = self.options.id
	local dir = self.installDir

	if not refresh and previous then
		return previous
	end

	-- TODO: Fetch gists/:id/commits [1].version first if we have a hash
	-- TODO: Worth storing individual versions?
	local success, request = platform.http.request("https://api.github.com/gists/" .. id)
	if not success or not request then
		context.logger:error("Cannot find gist " .. id)
		return false
	end

	local contents = request.readAll()
	request.close()

	local data = json.decode(contents)
	local hash = data.history[1].version
	local current

	if previous and hash == previous.hash then
		current = previous
	else
		current = { hash = hash, files = {} }
		for path, file in pairs(data.files) do
			if file.truncated then
				context.logger:error("Skipping " .. path .. " as it is truncated")
			else
				platform.fs.write(platform.fs.combine(dir, path), file.content)
				current.files[path] = true
			end
		end
	end

	return current
end


return {
	name = "gist package",
	description = "Allows downloading a gist dependency.",

	apply = function()
		Manager:addProvider(GistPackage, "gist")
	end,

	GistPackage = GistPackage,
}

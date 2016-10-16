--- A package provider that installs gists.
-- @module howl.modules.packages.gist

local class = require "howl.class"
local platform = require "howl.platform"

local Manager = require "howl.packages.Manager"
local Package = require "howl.packages.Package"

local PastebinPackage = Package:subclass("howl.modules.packages.gist.PastebinPackage")
	:addOptions { "id" }

--- Setup the dependency, checking if it cannot be resolved
function PastebinPackage:setup(context, runner)
	if not self.options.id then
		context.logger:error("Gist has no ID")
	end
end

function PastebinPackage:getName()
	return self.options.id
end

function PastebinPackage:files(previous)
	if previous then
		return {}
	else
		return { ["init.lua"] = true }
	end
end

function PastebinPackage:resolve(context, previous, refresh)
	local id = self.options.id
	local dir = self.installDir

	if not refresh and previous then
		return previous
	end

	local success, request = platform.http.request("http://pastebin.com/raw/" .. id)
	if not success or not request then
		context.logger:error("Cannot find pastebin " .. id)
		return previous
	end

	local contents = request.readAll()
	request.close()

	platform.fs.write(platform.fs.combine(dir, "init.lua"), contents)

	return { }
end


return {
	name = "pastebin package",
	description = "Allows downloading a pastebin dependency.",

	apply = function()
		Manager:addProvider(PastebinPackage, "pastebin")
	end,

	PastebinPackage = PastebinPackage,
}

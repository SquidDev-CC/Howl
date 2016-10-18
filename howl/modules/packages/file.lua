--- A package provider that uses a local file.
-- @module howl.modules.packages.file

local class = require "howl.class"
local fs = require "howl.platform".fs

local Manager = require "howl.packages.Manager"
local Package = require "howl.packages.Package"

local FilePackage = Package:subclass("howl.modules.packages.file.FilePackage")
	:addOptions { "path" }

--- Setup the dependency, checking if it cannot be resolved
function FilePackage:setup(context, runner)
	if not self.options.path then
		context.logger:error("No path specified")
	elseif self.options.path:sub(1, 1) ~= "/" then
		self.options.path = fs.combine(context.root, self.options.path)
	end
end

function FilePackage:getName()
	return (self.options.path:gsub("/", "-")) -- TODO: Prevent foo/bar clashing with foo-bar
end

function FilePackage:files(previous)
	return { [self.options.path] = self.options.path }
end

function FilePackage:require(context, previous, refresh)
	local id = self.options.id
	if not fs.exists(self.options.path) then
		context.logger:error("Cannot find file " .. self.options.path)
	end

	return true
end


return {
	name = "file package",
	description = "Allows using a local file as a dependency",

	apply = function()
		Manager:addProvider(FilePackage, "file")
	end,

	FilePackage = FilePackage,
}

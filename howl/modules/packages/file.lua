--- A package provider that uses a local file.
-- @module howl.modules.packages.file

local class = require "howl.class"
local mixin = require "howl.class.mixin"
local fs = require "howl.platform".fs

local Manager = require "howl.packages.Manager"
local Package = require "howl.packages.Package"
local Source = require "howl.files.Source"

local FilePackage = Package:subclass("howl.modules.packages.file.FilePackage")
	:include(mixin.filterable)
	:include(mixin.delegate("sources", {"from", "include", "exclude"}))

function FilePackage:initialize(context, root)
	Package.initialize(self, context, root)

	self.sources = Source(false)
	self.name = tostring({}):sub(8)
	self:exclude { ".git", ".svn", ".gitignore", context.out }
end

--- Setup the dependency, checking if it cannot be resolved
function FilePackage:setup(runner)
	if not self.sources:hasFiles() then
		self.context.logger:error("No files specified")
	end
end

function FilePackage:configure(item)
	Package.configure(self, item)
	self.sources:configure(item)
end

function FilePackage:getName()
	return self.name
end

function FilePackage:files(previous)
	local files = {}
	for _, v in pairs(self.sources:gatherFiles(self.context.root)) do
		files[v.name] = v.path
	end
	return files
end

function FilePackage:require(previous, refresh)
end


return {
	name = "file package",
	description = "Allows using a local file as a dependency",

	apply = function()
		Manager:addProvider(FilePackage, "file")
	end,

	FilePackage = FilePackage,
}

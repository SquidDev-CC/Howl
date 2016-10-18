--- An abstract package
-- @classmod howl.packages.Package

local class = require "howl.class"
local fs = require "howl.platform".fs
local mixin = require "howl.class.mixin"

local Package = class("howl.packages.Package")
	:include(mixin.configurable)
	:include(mixin.optionGroup)

--- Create a new package
function Package:initialize(root)
	if self.class == Package then
		error("Cannot create instance of abstract class " .. tostring(Package), 2)
	end

	self.root = root
	self.options = {}
end

--- Setup the package, checking if it is well formed
function Package:setup(context)
	error("setup has not been overridden in " .. tostring(self.class), 2)
end

--- Get a unique name for this package
-- @treturn string The unique name
function Package:getName()
	error("name has not been overridden in " .. tostring(self.class), 2)
end

--- Get the files for a set of metadata
-- @param cache The previous cache metadata
-- @treturn table Lookup of provided files to actual path. They should not have a leading '/'.
function Package:files(cache)
	error("files has not been overridden in " .. tostring(self.class), 2)
end

--- Resolve this package, fetching if required
-- @tparam howl.Context context The current context
-- @param previous The previous cache metadata
-- @tparam boolean refresh Force a refresh of dependencies
-- @return The new cache metadata
function Package:require(context, previous, refresh)
	error("require has not been overrriden in " .. tostring(self.class), 2)
end

return Package

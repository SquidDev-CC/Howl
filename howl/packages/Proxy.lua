--- A proxy to a package
-- @classmod howl.packages.Proxy

local class = require "howl.class"
local fs = require "howl.platform".fs
local mixin = require "howl.class.mixin"

local Proxy = class("howl.packages.Proxy")

--- Create a new package
function Proxy:initialize(manager, name, package)
	self.name = name
	self.manager = manager
	self.package = package
end

--- Get a unique name for this package
-- @treturn string The unique name
function Proxy:getName()
	return self.name
end

--- Get the files for a set of metadata
-- @treturn table Lookup of provided files to actual path. They should not have a leading '/'.
function Proxy:files()
	local cache = self.manager:getCache(self.name)
	return self.package:files(cache)
end

--- Resolve this package, fetching if required
-- @tparam [string] files List of required files
-- @tparam boolean force Force a refresh of dependencies
-- @return The list of files within the package
function Proxy:require(files, force)
	return self.manager:require(self.package, files, force)
end

return Proxy

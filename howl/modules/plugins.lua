--- A way of injecting plugins via the Howl DSL
-- @module howl.modules.plugins

local class = require "howl.class"
local mixin = require "howl.class.mixin"

local fs = require "howl.platform".fs

local Plugins = class("howl.modules.plugins")
	:include(mixin.configurable)

function Plugins:initialize(context)
	self.context = context
end

function Plugins:configure(data)
	if #data == 0 then
		self:addPlugin(data, data)
	else
		for i = 1, #data do
			self:addPlugin(data[i])
		end
	end
end

function Plugins:addPlugin(data)
	if not data.type then error("No plugin type specified") end

	local type = data.type
	data.type = nil

	local file
	if data.file then
		file = data.file
		data.file = nil
	end

	self.context.logger:verbose("Adding plugin type " .. type)
	local manager = self.context.packages
	local package = manager:addPackage(type, data)
	local fetchedFiles = manager:require(package, file and {file})

	if not file then
		if fetchedFiles["init.lua"] then
			file = "init.lua"
		else
			file = next(fetchedFiles)
		end
	end

	if not file then
		self.context.logger:error(package:getName() .. " does not export any files")
		error("Error adding plugin")
	end

	self.context.logger:verbose("Using package " .. package:getName() .. " with " .. file)
	local func, msg = loadfile(fetchedFiles[file], _ENV)
	if not func then
		self.context.logger:error("Cannot load plugin file " .. file .. ": " .. msg)
		error("Error adding plugin")
	end

	self.context:include(func())

	return self
end

return {
	name = "plugins",
	description = "Inject plugins into Howl at runtime.",

	setup = function(context)
		context.mediator:subscribe({ "HowlFile", "env" }, function(env)
			env.plugins = Plugins(context)
		end)
	end
}

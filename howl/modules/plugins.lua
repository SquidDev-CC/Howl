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

local function toModule(root, file)
	local name = file:gsub("%.lua$", ""):gsub("/", "."):gsub("^(.*)%.init$", "%1")
	if name == "" or name == "init" then
		return root
	else
		return root .. "." .. name
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

	local manager = self.context.packageManager
	local package = manager:addPackage(type, data)
	self.context.logger:verbose("Using plugin from package " .. package:getName())
	local fetchedFiles = package:require(file and {file})

	local root = "external." .. package:getName()

	for file, loc in pairs(fetchedFiles) do
		if file:find("%.lua$") then
			local func, msg = loadfile(fetchedFiles[file], _ENV)
			if func then
				local name = toModule(root, file)
				preload[name] = func
				self.context.logger:verbose("Including plugin file " .. file .. " as " .. name)
			else
				self.context.logger:warn("Cannot load plugin file " .. file .. ": " .. msg)
			end
		end
	end

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
	local name = toModule(root, file)
	if not preload[name] then
		self.context.logger:error("Cannot load plugin as " .. name .. " could not be loaded")
		error("Error adding plugin")
	end

	self.context:include(require(name))
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

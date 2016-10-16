--- Handles external packages
-- @module howl.packages.Manager

local class = require "howl.class"
local fs = require "howl.platform".fs
local dump = require "howl.lib.dump"
local mixin = require "howl.class.mixin"

local Manager = class("howl.packages.Manager")
Manager.providers = {}

function Manager:initialize(context)
	self.context = context

	self.packages = {}
	self.packageLookup = {}
	self.cache = {}
	self.root = ".howl/packages"
	self.alwaysRefresh = false
end

function Manager.static:addProvider(class, name)
	self.providers[name] = class
end

function Manager:addPackage(type, details)
	local provider = Manager.providers[type]
	if not provider then error("No such package provider " .. type, 2) end

	local package = provider()
	package:configure(details)
	local name = type .. "-" .. package:getName()
	package.installDir = fs.combine(self.root, name)

	self.packages[name] = package
	self.packageLookup[package] = name

	package:setup(self.context)
	if self.context.logger.hasError then
		error("Error setting up " .. name, 2)
	end

	return package
end

function Manager:require(package, files, force)
	local name = self.packageLookup[package]
	if not name then error("No such package " .. package:getName(), 2) end

	force = force or self.alwaysRefresh

	local data = self.cache[name]
	local path = fs.combine(self.root, name .. ".lua")
	if data == nil and fs.exists(path) then
		data = dump.unserialise(fs.read(path))
	end

	if data and files and not force then
		local existing = package:files(data)
		for _, file in ipairs(files) do
			if not existing[file] then
				force = true
				break
			end
		end
	end

	local newData = package:resolve(self.context, data, force)

	-- TODO: Decent equality checking
	if newData ~= data then
		self.context.logger:verbose("Package " .. name .. " updated")
		self.cache[name] = newData
		fs.write(path, dump.serialise(newData))
	end

	local newFiles = package:files(newData)
	if files then
		for _, file in ipairs(files) do
			if not newFiles[file] then
				error("Cannot resolve " .. file .. " for " .. name)
			end
		end
	end

	return newFiles
end

return Manager

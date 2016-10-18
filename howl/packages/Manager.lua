--- Handles external packages
-- @module howl.packages.Manager

local class = require "howl.class"
local fs = require "howl.platform".fs
local dump = require "howl.lib.dump"
local mixin = require "howl.class.mixin"

local Proxy = require "howl.packages.Proxy"

local emptyCache = {}

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

	local package = provider(self.context, self.root)
	package:configure(details)
	local name = type .. "-" .. package:getName()
	package.installDir = fs.combine(self.root, name)

	self.packages[name] = package
	self.packageLookup[package] = name

	package:setup(self.context)
	if self.context.logger.hasError then
		error("Error setting up " .. name, 2)
	end

	return Proxy(self, name, package)
end

function Manager:getCache(name)
	if not self.packages[name] then
		error("No such package " .. name, 2)
	end

	local cache = self.cache[name]
	local path = fs.combine(self.root, name .. ".lua")
	if cache == nil and fs.exists(path) then
		cache = dump.unserialise(fs.read(path))
	end

	if cache == emptyCache then cache = nil end

	return cache
end

function Manager:require(package, files, force)
	local name = self.packageLookup[package]
	if not name then error("No such package " .. package:getName(), 2) end

	force = force or self.alwaysRefresh

	local cache = self:getCache(name)

	if cache and files and not force then
		local existing = package:files(cache)
		for _, file in ipairs(files) do
			if not existing[file] then
				force = true
				break
			end
		end
	end

	local newData = package:require(cache, force)

	-- TODO: Decent equality checking
	if newData ~= cache then
		self.context.logger:verbose("Package " .. name .. " updated")
		if newData == nil then
			self.cache[name] = emptyCache
		else
			self.cache[name] = newData
			fs.write(fs.combine(self.root, name .. ".lua"), dump.serialise(newData))
		end
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

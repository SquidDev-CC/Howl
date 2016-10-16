--- Handles the whole Howl instance
-- @classmod howl.Context

local assert = require "howl.lib.assert"
local class = require "howl.class"
local mixin = require "howl.class.mixin"
local mediator = require "howl.lib.mediator"
local argparse = require "howl.lib.argparse"

local Logger = require "howl.lib.Logger"
local Manager = require "howl.packages.Manager"

local Context = class("howl.Context"):include(mixin.sealed)

--- Setup the main context
-- @tparam string root The project root of the directory
-- @tparam howl.lib.argparse args The argument parser
function Context:initialize(root, args)
	assert.type(root, "string", "bad argument #1 for Context expected string, got %s")
	assert.type(args, "table", "bad argument #2 for Context expected table, got %s")

	self.root = root
	self.out = "build"
	self.mediator = mediator
	self.arguments = argparse.Options(self.mediator, args)
	self.logger = Logger(self)
	self.packages = Manager(self)
end

--- Include a module in this context
-- @tparam string|table The module to include
function Context:include(module)
	if type(module) ~= "table" then
		module = require(module)
	end

	if not module.applied then
		self.logger:verbose("Including " .. module.name .. ": " .. module.description)
		module.applied = true
		if module.apply then module.apply() end
	end

	if module.setup then module.setup(self) end
end

return Context

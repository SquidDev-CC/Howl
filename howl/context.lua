--- Handles the whole Howl instance
-- @classmod howl.Context

local assert = require "howl.lib.assert"
local class = require "howl.lib.middleclass"
local mixin = require "howl.lib.mixin"
local mediator = require "howl.lib.mediator"
local argparse = require "howl.lib.argparse"

local Logger = require "howl.lib.logger"
local Context = class("howl.Context"):include(mixin.sealed)

--- Setup the main context
-- @tparam string root The project root of the directory
-- @tparam howl.lib.argparse args The argument parser
function Context:initialize(root, args)
	assert.type(root, "string", "bad argument #1 for Context expected string, got %s")
	assert.type(args, "table", "bad argument #2 for Context expected table, got %s")

	self.root = root
	self.mediator = mediator
	self.arguments = argparse.Options(self.mediator, args)
	-- self.Options = self.arguments
	self.logger = Logger(self)
end

return Context

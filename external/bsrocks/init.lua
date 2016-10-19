--- The main BSRocks extension bootstrapper
-- @module howl.external.bsrocks
local root = ...

local fs = require "howl.platform".fs

local BSRocksPackage = require(root .. ".BSRocksPackage")
local BustedTask = require(root .. ".BustedTask")
local LDocTask = require(root .. ".LDocTask")

local Manager = require "howl.packages.Manager"
local Runner = require "howl.tasks.Runner"

local function getRequire(context)
	local module = context:getModuleData("blue-shiny-rocks")

	if module.require then
		return module.require
	end

	local path = context.packageManager
		:addPackage("gist", { id = "6ced21eb437a776444aacef4d597c0f7" })
		:require({"bsrocks.lua"})
		["bsrocks.lua"]

	local bsrocks, err = loadfile(path, _ENV._NATIVE)

	if not bsrocks then
		context.logger:error("Cannot load bsrocks:" .. err)
		return
	end

	return bsrocks({}).require
end

return {
	name = "blue-shiny-rocks",
	description = "Basic interaction with Blue-Shiny-Rocks.",

	apply = function()
		Manager:addProvider(BSRocksPackage, "bs-rock")
		Runner:include {
			busted = function(self, name, taskDepends)
				return self:injectTask(BustedTask(self.env, name, taskDepends))
			end,
			ldoc = function(self, name, taskDepends)
				return self:injectTask(LDocTask(self.env, name, taskDepends))
			end,
		}
	end,

	setup = function(context, data)
		data.getRequire = function() return getRequire(context) end
	end,
}

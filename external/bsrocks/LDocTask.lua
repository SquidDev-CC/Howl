--- Adds a task to build LDoc documentation
-- @classmod howl.modules.bsrocks.LDocTask

local platform = require "howl.platform"

local Task = require "howl.tasks.Task"

local LDocTask = Task:subclass(...)
	:addOptions {
		'config',
		'output',
	}

function LDocTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.config = 'config.ld'
	self.output = platform.fs.combine(context.out, name)

	self:description "Generates documentation through LDoc"
end

function LDocTask:runAction(context)
	local brequire = context:getModuleData("blue-shiny-rocks").getRequire()
	if not brequire then
		context.logger:error("Cannot load BSRocks")
		error("Cannot load BSRocks", 0)
	end

	local path = context.packageManager
		:addPackage("bs-rock", { package = "ldoc" })
		:require({"ldoc.lua"})
		["ldoc.lua"]

	local env = brequire "bsrocks.env"()
	env.dir = context.root
	local thisEnv = env._G
	thisEnv.arg = {
		[0] = path,
		"--dir=/"..platform.fs.combine(context.root, self.options.output),
		"--config=/"..platform.fs.combine(context.root, self.options.config),
		".",
	}

	local func, err = loadfile(path, thisEnv)
	if not func then
		context.logger:error("Cannot load LDoc: " .. err)
		errror("Cannot load LDoc")
	end

	func(unpack(thisEnv.arg))

	for _, v in pairs(env.cleanup) do v() end
end

return LDocTask

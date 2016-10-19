--- Adds a task to execute busted tasks
-- @classmod howl.modules.bsrocks.BustedTask

local platform = require "howl.platform"

local Task = require "howl.tasks.Task"

local BustedTask = Task:subclass(...)
	:addOptions {
		'workingDirectory', 'directories',
		'sortTests',
		'randomize',
		'randomseed',
		'tags', 'excludeTags',
		'filter', 'excludeFilter',
		'pattern', 'excludePattern',
		'runs'
	}

function BustedTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self.workingDirectory = context.root
	self.directories = { "spec" }
	self.sortTests = false
	self.randomize = false
	self.randomseed = platform.os.time()
	self.tags = {}
	self.excludeTags = {}
	self.filter = {}
	self.excludeFilter = {}
	self.pattern = { "_spec" }
	self.excludePattern = {}
	self.runs = 1

	self:description "Runs tests using Busted"
end

function BustedTask:runAction(context)
	local brequire = context:getModuleData("blue-shiny-rocks").getRequire()
	if not brequire then
		context.logger:error("Cannot load BSRocks")
		error("Cannot load BSRocks", 0)
	end

	context.packageManager
		:addPackage("bs-rock", { package = "busted" })
		:require()

	local env = brequire "bsrocks.env"()
	env.dir = self.options.workingDirectory
	local thisEnv = env._G

	local erequire = thisEnv.require

	local busted = erequire 'busted.core'()
	busted.setDefaultEnvironment(_NATIVE)

	local filterLoader = erequire 'busted.modules.filter_loader'()
	local helperLoader = erequire 'busted.modules.helper_loader'()
	local outputHandlerLoader = erequire 'busted.modules.output_handler_loader'()
	local testFileLoader = erequire 'busted.modules.test_file_loader'(busted, {'lua'})
	local execute = erequire 'busted.execute'(busted)

	erequire 'busted'(busted)

	local failures = 0
	local errors = 0

	busted.subscribe({ 'error', 'output' }, function(element, parent, message)
		context.logger:error(appName .. ': error: Cannot load output library: ' .. element.name .. '\n' .. message .. '\n')
		return nil, true
	end)

	busted.subscribe({ 'error', 'helper' }, function(element, parent, message)
		context.logger:error(appName .. ': error: Cannot load helper script: ' .. element.name .. '\n' .. message .. '\n')
		return nil, true
	end)

	busted.subscribe({ 'error' }, function(element, parent, message)
		errors = errors + 1
		busted.skipAll = false
		return nil, true
	end)

	busted.subscribe({ 'failure' }, function(element, parent, message)
		if element.descriptor == 'it' then
			failures = failures + 1
		else
			errors = errors + 1
		end
		busted.skipAll = false
		return nil, true
	end)

	outputHandlerLoader(busted, 'utfTerminal', {
		defaultOutput = 'utfTerminal',
		verbose = context.logger.isVerbose,
		suppressPending = false,
		language = 'en',
		deferPrint = false,
		arguments = {},
	})

	filterLoader(busted, {
		tags = self.options.tags,
		excludeTags = self.options.excludeTags,
		filter = self.options.filter,
		filterOut = self.options.excludeFilter,
		list = false,
		nokeepgoing = false,
		suppressPending = false,
	})

	testFileLoader(self.options.directories, self.options.pattern, {
		excludes = self.options.excludePattern,
		verbose = context.logger.isVerbose,
		recursive = true,
	})

	execute(self.options.runs, {
		seed = self.options.randomseed,
		shuffle = self.options.randomize,
		sort = self.options.sort,
	})

	busted.publish({ 'exit' })

	for _, v in pairs(env.cleanup) do v() end

	if failures > 0 or errors > 0 then
		error("Tests failed!", 0)
	end
end

return BustedTask

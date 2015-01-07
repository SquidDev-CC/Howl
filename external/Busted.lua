--- Tasks for the lexer
-- @module external.Busted

local combine, resolve, exists, isDir, loadfile, verbose = fs.combine, shell.resolve, fs.exists, fs.isDir, loadfile, Utils.Verbose
local busted = busted

local names = {"busted.api.lua", "../lib/busted.api.lua", "busted.api", "../lib/busted.api", "busted", "../lib/busted"}

local function loadOneBusted(path)
	verbose("Busted at " .. path)
	local file = loadfile(path)
	if file then
		verbose("Busted loading at " .. path)
		local env = setmetatable({}, {__index = getfenv()})
		setfenv(file, env)()
		if env.run then
			verbose("Busted found at" .. path)
			return env
		end
	end
end

local function findOneBusted(folder)
	local absolute = resolve(folder)

	if not exists(folder) then return end
	if not isDir(folder) then
		return loadOneBusted(folder)
	end

	local path
	for name in ipairs(names) do
		path = combine(folder, name)
		if exists(path) then
			local bst = loadOneBusted(path)
			if bst then return bst end
		end
	end
end

local function findBusted()
	-- If busted exists already then don't worry
	if busted then return busted end

	-- Try to find a busted file in the root directory
	local bst = findOneBusted("/")
	if bst then
		busted = bst
		return busted
	end

	-- Try to find it on the shell path
	for path in string.gmatch(shell.path(), "[^:]+") do
		local bst = findOneBusted(path)
		if bst then
			busted = bst
			return busted
		end
	end
end

local function getDefaults()
	return {
		cwd = HowlFile.CurrentDirectory,
		output = 'colorTerminal',
		seed = os.time(),
		verbose = Utils.IsVerbose(),
		root = 'spec',
		tags = {},
		['exclude-tags'] = {},
		pattern = '_spec',
		loaders = {'lua'},
		helper = '',
	}
end

--- A task that minifies a source file
-- @tparam string name Name of the task
-- @tparam string inputFile The input file
-- @tparam string outputFile The file to save to
-- @tparam table taskDepends A list of @{tasks.Task.Task|tasks} this task requires
-- @treturn Runner.Runner The task runner (for chaining)
-- @see tasks.Runner.Runner
function Runner.Runner:Busted(name, options, taskDepends)
	return self:AddTask(name, taskDepends, function()
		local busted
		if options and options.busted then
			busted = findOneBusted(options.busted)
		else
			busted = findBusted()
		end
		if not busted then error("Cannot find busted") end

		local newOptions = getDefaults()
		for k,v in pairs(options or {}) do
			newOptions[k] = v
		end

		local count, errors = busted.run(newOptions, getDefaults())
		if count ~= 0 then
			Log(messages)
			error("Not all tests passed")
		end
	end)
		:Description("Runs tests")
end

--- Manages the running of tasks
-- @module tasks.Context

--- Holds task contexts
-- @type Context
local Context = {}

function Context:DoRequire(path, quite)
	if self.filesProduced[path] then return true end

	-- Check for normal files
	local task = self.producesCache[path]
	if task then
		self.filesProduced[path] = true
		return self:Run(task)
	end

	-- Check for file mapping
	task = self.normalMapsCache[path]
	local from, name
	local to = path
	if task then
		self.filesProduced[path] = true

		-- Convert task.Pattern.From to path
		-- (which should be task.Pattern.To)
		name = task.Name
		from = task.Pattern.From
	end

	for match, data in pairs(self.patternMapsCache) do
		if path:match(match) then
			self.filesProduced[path] = true

			-- Run task, replacing match with the replacement pattern
			name = data.Name
			from = path:gsub(match, data.Pattern.From)
			break
		end
	end

	if name then
		local canCreate = self:DoRequire(from, true)
		if not canCreate then
			if not quite then
				Utils.PrintError("Cannot find '" .. from .. "'")
			end
			return false
		end

		return self:Run(name, from, to)
	end

	if fs.exists(fs.combine(HowlFile.CurrentDirectory, path)) then
		self.filesProduced[path] = true
		return true
	end

	if not quite then
		Utils.PrintError("Cannot find a task matching '" .. path .. "'")
	end
	return false
end

--- Run a task
-- @tparam string|Task.Task name The name of the task or a Task object
-- @param ... The arguments to pass to it
-- @treturn boolean Success in running the task?
function Context:Run(name, ...)
	local task = name
	if type(name) == "string" then
		task = self.tasks[name]

		if not task then
			Utils.PrintError("Cannot find a task called '" .. name .."'")
			return false
		end
	elseif not task or not task.Run then
		Utils.PrintError("Cannot call task as it has no 'Run' method")
		return false
	end

	if self.ran[task] then return true end
	self.ran[task] = true

	-- Sleep before every task just in case
	Helpers.refreshYield()

	return task:Run(self, ...)
end

--- Start the task process
-- @tparam string name The name of the task (Optional)
-- @treturn boolean Success in running the task?
function Context:Start(name)
	local task
	if name then
		task = self.tasks[name]
	else
		task = self.default
		name = "<default>"
	end

	if not task then
		Utils.PrintError("Cannot find a task called '" .. name .. "'")
		return false
	end

	return self:Run(task)
end

--- Build a cache of tasks
-- This is used to speed up finding file based tasks
-- @treturn Context The current context
function Context:BuildCache()
	local producesCache = {}
	local patternMapsCache = {}
	local normalMapsCache = {}

	self.producesCache = producesCache
	self.patternMapsCache = patternMapsCache
	self.normalMapsCache = normalMapsCache

	for name, task in pairs(self.tasks) do
		local produces = task.produces
		if produces then
			for _, file in ipairs(produces) do
				local existing = producesCache[file]
				if existing then
					error(string.format("Both '%s' and '%s' produces '%s'", existing, name, file))
				end
				producesCache[file] = name
			end
		end

		local maps = task.maps
		if maps then
			for _, pattern in ipairs(maps) do
				-- We store two separate caches for each of them
				local toMap = (pattern.Type == "Pattern" and patternMapsCache or normalMapsCache)
				local match = pattern.To
				local existing = toMap[match]
				if existing then
					error(string.format("Both '%s' and '%s' match '%s'", existing, name, match))
				end
				toMap[match] = {Name = name, Pattern = pattern}
			end
		end
	end

	return self
end

--- Create a new task context
-- @tparam Runner.Runner runner The task runner to run tasks from
-- @treturn Context The resulting context
local function Factory(runner)
	return setmetatable({
		ran = {}, -- List of task already run
		filesProduced = {},
		tasks = runner.tasks,
		default = runner.default,

		Traceback = runner.Traceback,
		ShowTime = runner.ShowTime,
	}, {__index = Context}):BuildCache()
end

--- @export
return {
	Factory = Factory,
	Context = Context,
}

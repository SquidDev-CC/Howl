--- CC's platform table
-- @module howl.platform.cc

local default = term.getTextColor and term.getTextColor() or colors.white

local function read(file)
	local handle, err = fs.open(file, "r")
	if not handle then
		if not err:find(":") then err = file .. ": " .. tostring(err) end
		error(err, 2)
	end

	local contents = handle.readAll()
	handle.close()
	return contents
end

local function write(file, contents)
	local handle, err = fs.open(file, "w")
	if not handle then
		if not err:find(":") then err = file .. ": " .. tostring(err) end
		error(err, 2)
	end

	handle.write(contents)
	handle.close()
end

local function assertExists(file, name, level)
	if not fs.exists(file) then
		error("Cannot find " .. name .. " (Looking for " .. file .. ")", level or 1)
	end
end

local push, pull = os.queueEvent, coroutine.yield

local function refreshYield()
	push("sleep")
	if pull() == "terminate" then error("Terminated") end
end

local function readDir(directory)
	local offset = #directory + 2
	local stack, n = { directory }, 1

	local files = {}

	while n > 0 do
		local top = stack[n]
		n = n - 1

		if fs.isDir(top) then
			for _, file in ipairs(fs.list(top)) do
				n = n + 1
				stack[n] = fs.combine(top, file)
			end
		else
			files[top:sub(offset)] = read(top)
		end
	end

	return files
end

local function writeDir(dir, files)
	for file, contents in pairs(files) do
		write(fs.combine(dir, file), contents)
	end
end

local request= function(...)
	local ok, result, err_handle = http.post(...)
	if ok then
		return true, result
	else
		return false, err_handle, result
	end
end

local getEnv
if settings and fs.exists(".settings") then
	settings.load(".settings")
end

if settings and shell.getEnv then
	getEnv = function(name, default)
		local value = shell.getEnv(name)
		if value ~= nil then return value end

		return settings.get(name, default)
	end
elseif settings then
	getEnv = settings.get
elseif shell.getEnv then
	getEnv = function(name, default)
		local value = shell.getEnv(name)
		if value ~= nil then return value end
		return default
	end
else
	getEnv = function(name, default) return default end
end

local time
if profiler and profiler.milliTime then
	time = function() return profiler.milliTime() * 1e-3 end
else
	time = os.time
end

local log
if howlci then
	log = howlci.log
else
	log = function() end
end

return {
	os = {
		clock = os.clock,
		time = time,
		getEnv = getEnv,
	},
	fs = {
		-- Path manipulation
		combine = fs.combine,
		normalise = function(path) return fs.combine(path, "") end,
		getDir = fs.getDir,
		getName = fs.getName,
		currentDir = shell.dir,
		currentProgram = shell.getRunningProgram,

		-- File access
		read = read,
		write = write,
		readDir = readDir,
		writeDir = writeDir,
		getSize = fs.getSize,

		-- Type checking
		assertExists = assertExists,
		exists = fs.exists,
		isDir = fs.isDir,

		-- Other
		list = fs.list,
		makeDir = fs.makeDir,
		delete = fs.delete,
		move = fs.move,
		copy = fs.copy,
	},
	term = {
		setColor = function(color)
			local col = colours[color] or colors[color]
			if not col then error("Unknown color " .. color, 2) end

			term.setTextColor(col)
		end,
		resetColor = function() term.setTextColor(default) end,

		print = print,
		write = io.write,
	},
	http = {
		request = request,
	},
	log = log,

	refreshYield = refreshYield,
}

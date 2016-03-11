--- CC's platform table
-- @module howl.platform.cc

local default = term.getTextColor and term.getTextColor() or colors.white

local function read(file)
	local handle = fs.open(file, "r")
	local contents = handle.readAll()
	handle.close()
	return contents
end

local function write(file, contents)
	local handle = fs.open(file, "w")
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

return {
	fs = {
		-- Path manipulation
		combine = fs.combine,
		getDir = getDir,
		getName = getName,
		currentDir = shell.dir,

		-- File access
		read = read,
		write = write,
		readDir = readDir,
		writeDir = writeDir,

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
		resetColor = function() term.setTextColor(default) end
	},

	refreshYield = refreshYield,
}

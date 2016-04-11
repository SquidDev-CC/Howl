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

local request
if http.fetch then
	request = function(url, post, headers)
		local ok, err = http.fetch(url, post, headers)
		if ok then
			while true do
				local event, param1, param2, param3 = os.pullEvent(e)
				if event == "http_success" and param1 == url then
					return true, param2
				elseif event == "http_failure" and param1 == url then
					return false, param3, param2
				end
			end
		end
		return false, nil, err
	end
else
	request = function(...)
		local ok, result = http.post(...)
		if ok then
			return true, result
		else
			return false, nil, result
		end
	end
end


return {
	fs = {
		-- Path manipulation
		combine = fs.combine,
		normalise = function(path) return fs.combine(path, "") end,
		getDir = fs.getDir,
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
	http = {
		request = request,
	},

	refreshYield = refreshYield,
}

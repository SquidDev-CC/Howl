--- Platform implementation for vanilla Lua
-- @module howl.platform.native

local escapeBegin = string.char(27) .. '['
local colorMappings = {
	white     = 97,
	orange    = 33,
	magenta   = 95,
	lightBlue = 94,
	yellow    = 93,
	lime      = 92,
	pink      = 95, -- No pink
	gray      = 90, grey = 90,
	lightGray = 37, lightGrey = 37,
	cyan      = 96,
	purple    = 35, -- Dark magenta
	blue      = 36,
	brown     = 31,
	green     = 32,
	red       = 91,
	black     = 30,
}

local function notImplemented(name)
	return function() error(name .. " is not implemented", 2) end
end

local path = require('pl.path')
local dir = require('pl.dir')
local file = require('pl.file')
return {
	fs = {
		combine = path.join,
		normalise = path.normpath,
		getDir = path.dirname,
		getName = path.basename,
		currentDir = function() return path.currentdir end,

		read = file.read,
		write = file.write,
		readDir = notImplemented("fs.readDir"),
		writeDir = notImplemented("fs.writeDir"),

		assertExists = function(file)
			if not path.exists(file) then
				error("File does not exist")
			end
		end,
		exists = path.exists,
		isDir = path.isdir,

		-- Other
		list = function(dir)
			local result = {}
			for path in path.dir(dir) do
				result[#result + 1] = path
			end

			return result
		end,
		makeDir = dir.makepath,
		delete = function(pa)
			if path.isdir(pa) then
				dir.rmtree(pa)
			else
				file.delete(pa)
			end
		end,
		move = file.move,
		copy = file.copy,
	},

	http = {
		request = notImplemented("http.request"),
	},

	term = {
		setColor = function(color)
			local col = colorMappings[color]
			if not col then error("Cannot find color " .. tostring(color), 2) end
			io.write(escapeBegin .. col .. "m")
			io.flush()
		end,
		resetColor = function()
			io.write(escapeBegin .. "0m")
			io.flush()
		end
	},
	refreshYield = function() end
}

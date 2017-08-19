--- OpenComputers's platform table
-- @module howl.platform.oc

local filesystem = require("filesystem")
local term = require("term")
local component = require("component")
local hasInternet = pcall(function() return component.internet end)
local internet = require("internet")
local gpu = component.gpu

local function read(filename)
  local size = getSize(filename)
  local fh = filesystem.open(filename)
  local contents = fh:read(size)
  fh:close()
  return contents
end

--readDir and writeDir copied semi-verbatim from CC platform (with a slight modification)
local function readDir(directory)
	local offset = #directory + 2
	local stack, n = { directory }, 1

	local files = {}

	while n > 0 do
		local top = stack[n]
		n = n - 1

		if fs.isDir(top) then
			for _, file in ipairs(filesystem.list(top)) do
				n = n + 1
				stack[n] = filesystem.combine(top, file)
			end
		else
			files[top:sub(offset)] = read(top)
		end
	end

	return files
end

local function writeDir(dir, files)
	for file, contents in pairs(files) do
		write(filesystem.combine(dir, file), contents)
	end
end

local function write(filename,contents)
  local fh = filesystem.open(filename,"w")
  local ok, err = fh:write(contents)
  if not ok then io.stderr:write(err) end
  fh:close()
end

local function assertExists(file,name,level)
  if not filesystem.exists(file) then
    error("Cannot find "..name.." (looking for "..file..")",level or 1)
  end
end

local function getSize(file)
  local fh = filesystem.open(file)
  local size = fh:seek("end")
  fh:close()
  return size
end

local function notImplemented(name)
  return function() error(name.." has not been implemented for OpenComputers!",2) end
end

return {
	os = {
		clock = os.clock,
		time = os.time,
		getEnv = os.getEnv,
	},
	fs = {
		-- Path manipulation
		combine = filesystem.concat,
		normalise = filesystem.canonical,
		getDir = filesystem.path,
		getName = filesystem.name,
		currentDir = shell.getWorkingDirectory,
		currentProgram = notImplemented("fs.currentProgram"),

		-- File access
		read = read,
		write = write,
		readDir = readDir,
		writeDir = writeDir,
		getSize = getSize,

		-- Type checking
		assertExists = assertExists,
		exists = filesystem.exists,
		isDir = filesystem.isDir,

		-- Other
		list = filesystem.list,
		makeDir = filesystem.makeDir,
		delete = filesystem.delete,
		move = filesystem.move,
		copy = filesystem.copy,
	},
	term = {
		setColor = gpu.setForeground,
		resetColor = function() gpu.setForeground(colors.white) end,

		print = print,
		write = io.write,
	},
	http = {
		request = notImplemented("http.request"),
	},
	log = function() return end,

	refreshYield = function() os.sleep(0) end,
}

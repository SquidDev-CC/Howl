--- OpenComputers's platform table
-- @module howl.platform.oc

local filesystem = require("filesystem")
local term = require("term")
local component = require("component")
local hasInternet, internet = pcall(function() return component.internet end)

local function read(filename)
  local fh = filesystem.open(filename)
  local end = fh:seek("end")
  fh:seek("set")
  local contents = fh:read(end)
  fh:close()
  return contents
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

local function notImplemented(name)
  return function() error(name.." has not been implemented for OpenComputers!") end
end

return {
	os = {
		clock = notImplemented("os.clock"),
		time = notImplemented("os.time"),
		getEnv = notImplemented("os.getEnv"),
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
		readDir = notImplemented("fs.readDir"),
		writeDir = notImplemented("fs.writeDir"),
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
		setColor = notImplemented("term.setColor"),
		resetColor = notImplemented("term.resetColor"),

		print = print,
		write = io.write,
	},
	http = {
		request = notImplemented("http.request"),
	},
	log = notImplemented("log"),

	refreshYield = function() os.sleep(0) end,
}

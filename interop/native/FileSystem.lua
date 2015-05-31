--- Emulates core elements of the fs API
-- Requires Penlight
-- @module interop.FileSystem

require('pl')

--[[
	fs.list(string path)	table files	Returns a list of all the files (including subdirectories but not their contents) contained in a directory, as a numerically indexed table.
	fs.exists(string path)	boolean exists	Checks if a path refers to an existing file or directory.
	fs.isDir(string path)	boolean isDirectory	Checks if a path refers to an existing directory.
	fs.getName(string path)	string name	Gets the final component of a pathname.
	fs.makeDir(string path)	nil	Makes a directory.
	fs.move(string fromPath, string toPath)	nil	Moves a file or directory to a new location.
	fs.copy(string fromPath, string toPath)	nil	Copies a file or directory to a new location.
	fs.delete(string path)	nil	Deletes a file or directory.
	fs.combine(string basePath, string localPath)	string path	Combines two path components, returning a path consisting of the local path nested inside the base path.
	fs.open(string path, string mode)	table handle	Opens a file so it can be read or written.
	fs.find(string wildcard)	table files	Searches the computer's files using wildcards. Requires version 1.6 or later.
	fs.getDir(string path)	string parentDirectory	Returns the parent directory of path. Requires version 1.63 or later.
]]

local function list(dir)
	local result = {}
	for path in path.dir(dir) do
		table.insert(result, path)
	end

	return result
end

local function open(p, mode)
	local handle, result
	local isOpen = true
	if mode == "w" or mode == "a" then
		local dirname = path.dirname(p)
		if not path.exists(dirname) then path.mkdir(dirname) end

		result = {
			write = function(msg)
				if not isOpen then error("Stream closed", 2) end
				handle:write(tostring(msg))
			end,

			writeLine = function(msg)
				if not isOpen then error("Stream closed", 2) end
				handle:write(tostring(msg) .. "\n")
			end,

			flush = function()
				if not isOpen then return end
				handle:flush()
			end,
		}
	elseif mode == "wb" or mode == "ab" then
		local dirname = path.dirname(p)
		if not path.exists(dirname) then path.mkdir(dirname) end

		result = {
			write = function(number)
				if not isOpen then return end
				handle:write(string.char(number))
			end,

			flush = function()
				if not isOpen then return end
				handle:flush()
			end,
		}
	elseif mode == "r" then
		result = {
			readLine = function()
				if not isOpen then return end
				return handle:read("*l")
			end,

			readAll = function()
				if not isOpen then return end
				return handle:read("*a")
			end,
		}
	elseif mode == "rb" then
		result = {
			read = function()
				if not isOpen then return end
				local char =  handle:read(1)
				if char ~= nil then return string.byte(char) end
				return nil
			end,
		}
	end

	handle = io.open(p, mode)
	if handle then
		result.close = function()
			if not isOpen then return end
			isOpen = false
			handle:close()
		end
		return result
	end

	return nil
end

local function combine(...)
	return path.normpath(path.join(...))
end

local function delete(file)
	if path.exists(file) then dir.rmtree(file) end
end

local function mkdir(dir)
	if not path.exists(dir) then
		builder = ''
		for _, sub in ipairs(split(dir, '/')) do
			builder = path.join(builder, sub)
			path.mkdir(builder)
		end
	end
end

return {
	list        = list,
	exists      = path.exists,
	isDir       = path.isdir,
	getName     = path.basename,
	makeDir     = mkdir,
	move        = file.move,
	copy        = file.copy,
	delete      = delete,
	combine     = combine,
	open        = open,
	getDir      = path.dirname,
}

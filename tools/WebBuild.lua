--- Clone a repository and build it


-- Print verbose
local doVerbose = false
local function verbose(...)
	if doVerbose then print(...) end
end

--Credit goes to http://www.computercraft.info/forums2/index.php?/topic/5854-json-api-v201-for-computercraft/
local downloadJson
do
	------------------------------------------------------------------ utils
	local controls = {["\n"]="\\n", ["\r"]="\\r", ["\t"]="\\t", ["\b"]="\\b", ["\f"]="\\f", ["\""]="\\\"", ["\\"]="\\\\"}


	local whites = {['\n']=true; ['r']=true; ['\t']=true; [' ']=true; [',']=true; [':']=true}
	local function removeWhite(str)
		while whites[str:sub(1, 1)] do
			str = str:sub(2)
		end
		return str
	end

	------------------------------------------------------------------ decoding
	local jsonParseValue
	local function jsonParseBoolean(str)
		if str:sub(1, 4) == "true" then
			return true, removeWhite(str:sub(5))
		else
			return false, removeWhite(str:sub(6))
		end
	end

	local function jsonParseNull(str)
		return nil, removeWhite(str:sub(5))
	end

	local numChars = {['e']=true; ['E']=true; ['+']=true; ['-']=true; ['.']=true}
	local function jsonParseNumber(str)
		local i = 1
		while numChars[str:sub(i, i)] or tonumber(str:sub(i, i)) do
			i = i + 1
		end
		local val = tonumber(str:sub(1, i - 1))
		str = removeWhite(str:sub(i))
		return val, str
	end

	local function jsonParseString(str)
		local i,j = str:find('^".-[^\\]"')
		local s = str:sub(i + 1,j - 1)

		for k,v in pairs(controls) do
			s = s:gsub(v, k)
		end
		str = removeWhite(str:sub(j + 1))
		return s, str
	end

	local function jsonParseArray(str)
		str = removeWhite(str:sub(2))

		local val = {}
		local i = 1
		while str:sub(1, 1) ~= "]" do
			local v = nil
			v, str = jsonParseValue(str)
			val[i] = v
			i = i + 1
			str = removeWhite(str)
		end
		str = removeWhite(str:sub(2))
		return val, str
	end

	local function jsonParseMember(str)
		local k = nil
		k, str = jsonParseValue(str)
		local val = nil
		val, str = jsonParseValue(str)
		return k, val, str
	end

	local function jsonParseObject(str)
		str = removeWhite(str:sub(2))

		local val = {}
		while str:sub(1, 1) ~= "}" do
			local k, v = nil, nil
			k, v, str = jsonParseMember(str)
			val[k] = v
			str = removeWhite(str)
		end
		str = removeWhite(str:sub(2))
		return val, str
	end

	function jsonParseValue(str)
		local fchar = str:sub(1, 1)
		if fchar == "{" then
			return jsonParseObject(str)
		elseif fchar == "[" then
			return jsonParseArray(str)
		elseif tonumber(fchar) ~= nil or numChars[fchar] then
			return jsonParseNumber(str)
		elseif str:sub(1, 4) == "true" or str:sub(1, 5) == "false" then
			return jsonParseBoolean(str)
		elseif fchar == "\"" then
			return jsonParseString(str)
		elseif str:sub(1, 4) == "null" then
			return jsonParseNull(str)
		end
		return nil
	end

	local function jsonDecode(str)
		str = removeWhite(str)
		t = jsonParseValue(str)
		return t
	end

	downloadJson = function(url)
		verbose("Getting ", url)
		local file = http.get(url)
		if not file then
			return nil
		end
		return jsonDecode(file.readAll())
	end
end

local howlPath = shell.resolveProgram("Howl") or "/H"
if not howlPath then
	error("Cannot find Howl installation")
end

-- Store the number of rebuilds
local retries = 2

-- The current branch
local branch = "master"

-- The task to run
local task = "WebBuild"

local repo

-- Parse the arguments
local args = {...}
local index, length = 1, #args
while index <= length do
	local arg = args[index]

	if arg == "--branch" or arg == "-branch" or arg == "-b" then
		index = index + 1
		branch = args[index]
	elseif arg == "--repo" or arg == "-repo" or arg == "-r" then
		index = index + 1
		repo = args[index]
	elseif arg == "--retries" or arg == "-retries" then
		index = index + 1
		retries = tostring(args[index]) or 2
	elseif arg == "--verbose" or arg == "-verbose" or arg == "-v" then
		doVerbose = true
	elseif arg == "--task" or arg == "-task" or arg == "-t" then
		index = index + 1
		task = tostring(args[index]) or 2
	elseif not repo then
		repo = arg
	elseif not branch then
		branch = arg
	else
		error("Unexpected argument " .. arg)
	end

	index = index + 1
end

-- Use 'default task' if mentioned explicitly
if task == "default" then
	task = nil
end

assert(repo, "Must specify a repo")

local getRaw = 'https://raw.github.com/'..repo..'/'..branch..'/'
local args = {...}

local tree

--Get tree
--Download file list
for i = 1, retries do
	local result = downloadJson('https://api.github.com/repos/'..repo..'/git/trees/'..branch..'?recursive=1')
	if result and result.tree then
		tree = result.tree
		break
	end
end

if not tree then
	error("Could not fetch tree. Does the branch exist?")
end

local function download(fileList)
	print("Start download")

	local tree = {}
	local files = {}

	local count = 0
	local total = 0
	local function redraw()
		term.clearLine()
		local x, y = term.getCursorPos()
		term.setCursorPos(1, y)
		write(string.format("%i/%i (%g%%)", count, total, count / total * 100))
	end

	-- Download a file and store it in the tree
	local function download(file)
		local path = file.path
		-- Ignore directories
		if file.type == 'tree' then
			files[path] = true
		else
			local contents

			-- Attempt to download the file
			for i = 1, retries do
				local url = (getRaw .. path):gsub(' ','%%20')
				local f = http.get(url)

				if f then
					contents = f.readAll()
					break
				end

				verbose("Retrying ", path)
			end

			if not contents then error("Cannot download " .. path) end

			-- Increment counter
			count = count + 1
			redraw()

			-- Find directory node
			local root = tree
			local nodes = {path:match((path:gsub("[^/]+/?", "([^/]+)/?")))}
			nodes[#nodes] = nil
			for _, node in pairs(nodes) do
				local nRoot = root[node]
				if not nRoot then
					nRoot = {}
					root[node] = nRoot
				end
				root = nRoot
			end

			--Write file to both tree and files. The tree is only used for fs.list so we keep it simple
			root[fs.getName(path)] = true
			files[path] = contents
		end
	end

	local callbacks = {}

	for _, file in ipairs(fileList) do
		total = total + 1
		callbacks[total] = function() download(file) end
	end

	parallel.waitForAll(unpack(callbacks))

	-- Reset line
	term.clearLine()
	local x, y = term.getCursorPos()
	term.setCursorPos(1, y)

	print("Finshed downloading")

	return tree, files
end

--Prepare file download
local foundHowl = false
for _, file in ipairs(tree) do
	if file.path == "Howlfile.lua" or file.path == "Howlfile" and file.type ~= "type" then
		foundHowl = true
		break
	end
end

if not foundHowl then
	error("Cannot find a Howlfile. It must be in the root of the project")
end

local tree, files = download(tree)

local root = shell.dir()

-- Emulated filesystem (partially based of Oeed's)
local fs = fs
local env
env = {
	fs = {
		list = function(path)
			if fs.exists(path) then
				list = fs.list(path)
			end

			if path == root or path:sub(1, #root + 1) == root .. "/" then
				path = path:sub(#root)

				local root = tree
				local nodes = {path:match((path:gsub("[^/]+/?", "([^/]+)/?")))}
				nodes[#nodes] = nil
				for _, node in pairs(nodes) do
					local nRoot = root[node]
					if not nRoot then
						return list
					end
					root = nRoot
				end

				for k, _ in ipairs(root) do
					list[#list + 1] = k
				end
			end

			return list
		end,

		exists = function(path)
			if fs.exists(path) then
				return true
			elseif path == root or path:sub(1, #root + 1) == root .. "/" then
				path = path:sub(#root + 2) -- / and 1 offset
				return files[path] ~= nil
			end
		end,

		isDir = function(path)
			if fs.isDir(path) then
				return true
			elseif path == root or path:sub(1, #root + 1) == root .. "/" then
				path = path:sub(#root + 2)
				return files[path] == true
			end
		end,

		isReadOnly = function(path)
			if not fs.isReadOnly(path) then
				return false
			else
				return true
			end
		end,

		getName = fs.getName,
		getDir = fs.getDir,
		getSize = fs.getSize,
		getFreespace = fs.getFreespace,
		makeDir = fs.makeDir,
		move = fs.move,
		copy = fs.copy,
		delete = fs.delete,
		combine = fs.combine,

		open = function(path, mode)
			if fs.exists(path) then
				return fs.open(path, mode)
			elseif path == root or path:sub(1, #root + 1) == root .. "/" then
				local subPath = path:sub(#root + 2)

				if type(files[subPath]) == 'string' then
					local handle = {close = function()end}
					if mode == 'r' then
						local content = files[subPath]
						handle.readAll = function()
							return content
						end

						local line = 1
						local lines
						handle.readLine = function()
							if not lines then -- Lazy load lines
								lines = {content:match((content:gsub("[^\n]+\n?", "([^\n]+)\n?")))}
							end
							if line > #lines then
								return nil
							else
								return lines[line]
							end
							line = line + 1
						end

						return handle
					else
						error('Cannot write to read-only file.', 2)
					end
				else
					return fs.open(path, mode)
				end
			else
				return fs.open(path, mode)
			end
		end
	},

	loadfile = function( _sFile )
		local file = env.fs.open( _sFile, "r" )
		if file then
				local func, err = loadstring( file.readAll(), fs.getName( _sFile ) )
				file.close()
				return func, err
		end
		return nil, "File not found: ".._sFile
	end,

	dofile = function( _sFile )
		local fnFile, e = env.loadfile( _sFile )
		if fnFile then
				setfenv( fnFile, getfenv(2) )
				return fnFile()
		else
				error( e, 2 )
		end
	end
}

verbose("Running with " .. task)
setfenv(loadfile(howlPath), setmetatable(env, {__index = getfenv()}))(task, doVerbose and "-v" or nil)

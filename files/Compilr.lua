--- [Compilr](https://github.com/oeed/Compilr) by Oeed ported to Howl by SquidDev
-- Combines files and emulates the fs API
-- @module files.Compilr

local header = [=[--[[Hideously Smashed Together by Compilr, a Hideous Smash-Stuff-Togetherer, (c) 2014 oeed
	This file REALLLLLLLY isn't suitable to be used for anything other than being executed
	To extract all the files, run: "<filename> --extract" in the Shell
]]
]=]

local footer = [[
local function run(tArgs)
	local fnFile, err = loadstring(files[%q], %q)
	if err then error(err) end

	local function split(str, pat)
		 local t = {}
		 local fpat = "(.-)" .. pat
		 local last_end = 1
		 local s, e, cap = str:find(fpat, 1)
		 while s do
				if s ~= 1 or cap ~= "" then
		 table.insert(t,cap)
				end
				last_end = e+1
				s, e, cap = str:find(fpat, last_end)
		 end
		 if last_end <= #str then
				cap = str:sub(last_end)
				table.insert(t, cap)
		 end
		 return t
	end

	local function resolveTreeForPath(path, single)
		local _files = files
		local parts = split(path, '/')
		if parts then
			for i, v in ipairs(parts) do
				if #v > 0 then
					if _files[v] then
						_files = _files[v]
					else
						_files = nil
						break
					end
				end
			end
		elseif #path > 0 and path ~= '/' then
			_files = _files[path]
		end
		if not single or type(_files) == 'string' then
			return _files
		end
	end

	local oldFs = fs
	local env
	env = {
		fs = {
			list = function(path)
							local list = {}
							if fs.exists(path) then
						list = fs.list(path)
							end
				for k, v in pairs(resolveTreeForPath(path)) do
					if not fs.exists(path .. '/' ..k) then
						table.insert(list, k)
					end
				end
				return list
			end,

			exists = function(path)
				if fs.exists(path) then
					return true
				elseif resolveTreeForPath(path) then
					return true
				else
					return false
				end
			end,

			isDir = function(path)
				if fs.isDir(path) then
					return true
				else
					local tree = resolveTreeForPath(path)
					if tree and type(tree) == 'table' then
						return true
					else
						return false
					end
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
				elseif type(resolveTreeForPath(path)) == 'string' then
					local handle = {close = function()end}
					if mode == 'r' then
						local content = resolveTreeForPath(path)
						handle.readAll = function()
							return content
						end

						local line = 1
						local lines = split(content, '\n')
						handle.readLine = function()
							if line > #lines then
								return nil
							else
								return lines[line]
							end
							line = line + 1
						end
											return handle
					else
						error('Cannot write to read-only file (compilr archived).')
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

	setmetatable( env, { __index = _G } )

	local tAPIsLoading = {}
	env.os.loadAPI = function( _sPath )
			local sName = fs.getName( _sPath )
			if tAPIsLoading[sName] == true then
					printError( "API "..sName.." is already being loaded" )
					return false
			end
			tAPIsLoading[sName] = true

			local tEnv = {}
			setmetatable( tEnv, { __index = env } )
			local fnAPI, err = env.loadfile( _sPath )
			if fnAPI then
					setfenv( fnAPI, tEnv )
					fnAPI()
			else
					printError( err )
					tAPIsLoading[sName] = nil
					return false
			end

			local tAPI = {}
			for k,v in pairs( tEnv ) do
					tAPI[k] =  v
			end

			env[sName] = tAPI
			tAPIsLoading[sName] = nil
			return true
	end

	env.shell = shell

	setfenv( fnFile, env )
	fnFile(unpack(tArgs))
end

local function extract()
		local function node(path, tree)
				if type(tree) == 'table' then
						fs.makeDir(path)
						for k, v in pairs(tree) do
								node(path .. '/' .. k, v)
						end
				else
						local f = fs.open(path, 'w')
						if f then
								f.write(tree)
								f.close()
						end
				end
		end
		node('', files)
end

local tArgs = {...}
if #tArgs == 1 and tArgs[1] == '--extract' then
	extract()
else
	run(tArgs)
end
]]

function Files.Files:Compilr(output, options)
	local path = self.path
	options = options or {}

	local files = self:Files()
	if not files[self.startup] then
		error('You must have a file called ' .. self.startup .. ' to be executed at runtime.')
	end

	local resultFiles = {}
	for file, _ in pairs(files) do
		local read = fs.open(fs.combine(path, file), "r")
		local contents = read.readAll()
		read.close()

		if options.minify and loadstring(contents) then -- This might contain non-lua files, ensure it doesn't
			contents = Rebuild.MinifyString(contents)
		end

		local root = resultFiles
		local nodes = {file:match((file:gsub("[^/]+/?", "([^/]+)/?")))}
		nodes[#nodes] = nil
		for _, node in pairs(nodes) do
			local nRoot = root[node]
			if not nRoot then
				nRoot = {}
				root[node] = nRoot
			end
			root = nRoot
		end

		root[fs.getName(file)] = contents
	end

	local result = header .. "local files = " .. Helpers.serialize(resultFiles) .. "\n" .. string.format(footer, self.startup, self.startup)

	if options.minify then
		result = Rebuild.MinifyString(result)
	end

	local outputFile = fs.open(fs.combine(HowlFile.CurrentDirectory, output), "w")
	outputFile.write(result)
	outputFile.close()
end

function Runner.Runner:Compilr(name, files, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function()
		files:Compilr(outputFile)
	end)
		:Description("Combines multiple files using Compilr")
		:Produces(outputFile)
end

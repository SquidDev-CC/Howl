--- Utility to bootstrap howl

local loading = {}
local oldRequire, preload, loaded = require, {}, {}

local function require(name)
	local result = loaded[name]

	if result ~= nil then
		if result == loading then
			error("loop or previous error loading module '" .. name .. "'", 2)
		end

		return result
	end

	loaded[name] = loading
	local contents = preload[name]
	if contents then
		result = contents(name)
	elseif oldRequire then
		result = oldRequire(name)
	else
		error("cannot load '" .. name .. "'", 2)
	end

	if result == nil then result = true end
	loaded[name] = result
	return result
end
local sandEnv = setmetatable({
	_G = _G,
	_NATIVE = _ENV or _G,
	require = require, preload = preload,
	assert = assert,
	error = error,
	getmetatable = getmetatable,
	ipairs = ipairs,
	loadstring = loadstring, loadfile = loadfile, -- Try to avoid using these
	math = math,
	next = next,
	pairs = pairs,
	pcall = pcall,
	print = print,
	rawequal = rawequal, rawget = rawget, rawset = rawset,
	require = require,
	select = select,
	setmetatable = setmetatable,
	string = string,
	table = table,
	tonumber = tonumber, tostring = tostring,
	type = type,
	unpack = unpack,
	xpcall = xpcall,
}, {
	__index = function(_, name) error("Attempt to get global " .. name, 2) end,
	__newindex = function(self, name, value)
		if name == "_ENV" then
			rawset(self, name, value)
		else
			error("Attempt to set global " .. name, 2)
		end
	end,
})

local globalEnv = setmetatable({ require = require }, { __index = _ENV })
local root = fs.getDir(shell.getRunningProgram())

local function toModule(file)
	if root ~= "" then file = file:sub(#root + 2) end
	return file:gsub("%.lua$", ""):gsub("/", "."):gsub("^(.*)%.init$", "%1")
end

local function toResource(file)
	if root ~= "" then file = file:sub(#root + 2) end
	return file:gsub("%.res%.lua$", ""):gsub("/", "."):gsub("^(.*)%.init$", "%1")
end

local function loadModule(path, global)
	local file = fs.open(path, "r")
	if file then
		local env = sandEnv
		if root ~= "" then path = path:sub(#root + 2) end
		if global or path:find("howl/platform/", 1, true) then env = globalEnv end
		local func, err = load(file.readAll(), path, "t", env)
		file.close()
		if not func then error(err) end
		return func
	end
	error("File not found: " .. tostring(path))
end

local function loadResource(path)
	local file = fs.open(path, "r")
	if file then
		local contents = file.readAll()
		file.close()
		return function() return contents end
	end
	error("File not found: " .. tostring(path))
end

local function include(path)
	if fs.isDir(path) then
		for _, v in ipairs(fs.list(path)) do
			include(fs.combine(path, v))
		end
	elseif path:find("%.res%.lua$") then
		preload[toResource(path)] = loadResource(path)
	elseif path:find("%.lua$") then
		preload[toModule(path)] = loadModule(path)
	end
end

include(fs.combine(root, "howl"))
local args = { ... }

if args[1] == "repl" then
	preload["howl.cli"] = loadModule(shell.resolveProgram("lua"), true)
	args = {}
elseif args[1] == "exec" then
	preload["howl.cli"] =  loadModule(shell.resolveProgram(args[2]))
	args = {}
end

local success = xpcall(function()
	preload["howl.cli"](unpack(args))
end, function(err)
	printError(err)
	for i = 3, 15 do
		local _, msg = pcall(error, "", i)
		if #msg == 0 or msg:find("^xpcall:") then break end
		print(" ", msg)
	end
end)

if not success then error() end

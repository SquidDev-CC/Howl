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
		result = contents()
	elseif oldRequire then
		result = oldRequire(name)
	else
		error("cannot load '" .. name .. "'", 2)
	end

	if result == nil then result = true end
	loaded[name] = result
	return result
end
local env = setmetatable({ require = require }, { __index = getfenv() })
local root = fs.getDir(shell.getRunningProgram())

local function toModule(file)
	return file:sub(#root + 2):gsub("%.lua$", ""):gsub("/", "."):gsub("^(.*)%.init$", "%1")
end

local function loadModule(path)
	local file = fs.open(path, "r")
	if file then
		local func, err = load(file.readAll(), path:sub(#root + 2), "t", env)
		file.close()
		if not func then error(err) end
		return func
	end
	error("File not found: " .. tostring(path))
end

local function include(path)
	if fs.isDir(path) then
		for _, v in ipairs(fs.list(path)) do
			include(fs.combine(path, v))
		end
	elseif path:find("%.lua$") then
		preload[toModule(path)] = loadModule(path)
	end
end

include(fs.combine(root, "howl"))
local args = { ... }

if args[1] == "repl" then
	preload["howl.cli"] = loadModule(shell.resolveProgram("lua"))
elseif args[1] == "exec" then
	preload["howl.cli"] =  loadModule(shell.resolveProgram(args[2]))
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

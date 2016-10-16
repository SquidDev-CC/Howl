--- [Compilr](https://github.com/oeed/Compilr) by Oeed ported to Howl by SquidDev
-- Combines files and emulates the fs API
-- @module howl.files.compilr

local Files = require "howl.files"
local dump = require "howl.lib.dump"
local Rebuild = require "howl.lexer.rebuild"
local Runner = require "howl.tasks.Runner"
local formatTemplate = require "howl.lib.utils".formatTemplate

local template = require "howl.modules.compilr.template"

function Files:Compilr(env, output, options)
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
		local nodes = { file:match((file:gsub("[^/]+/?", "([^/]+)/?"))) }
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

	local result = formatTemplate(template, {
		files = dump.serialise(resultFiles),
		startup = ("%q"):format(self.startup)
	})

	if options.minify then
		result = Rebuild.MinifyString(result)
	end

	local outputFile = fs.open(fs.combine(env.root, output), "w")
	outputFile.write(result)
	outputFile.close()
end

function Runner:Compilr(name, files, outputFile, taskDepends)
	return self:AddTask(name, taskDepends, function(task, env)
		files:Compilr(env, outputFile)
	end)
		:Description("Combines multiple files using Compilr")
		:Produces(outputFile)
end

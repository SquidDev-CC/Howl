--- [Compilr](https://github.com/oeed/Compilr) by Oeed ported to Howl by SquidDev
-- Combines files and emulates the fs API
-- @module files.Compilr

local header = [=[
local loading = {}
local oldRequire, preload, loaded = require, {}, { startup = loading }

local function require(name)
	local result = loaded[name]

	if result ~= nil then
		if result == loading then
			error("loop or previous error loading module ' " .. name .. "'", 2)
		end

		return result
	end

	loaded[name] = loading
	local contents = preload[name]
	if contents then
		result = contents()
	elseif require then
		result = require(name)
	else
		error("cannot load '" + name + "'")
	end

	if result == nil then result = true end
	loaded[name] = result
	return result
end
]=]


function Files.Files:AsRequire(env, output, options)
	local path = self.path
	options = options or {}
	local link = options.Link

	local files = self:Files()
	if not files[self.startup] then
		error('You must have a file called ' .. self.startup .. ' to be executed at runtime.')
	end

	local result = {header}
	for file, _ in pairs(files) do
		Utils.Verbose("Including " .. file)
		local whole = fs.combine(path, file)
		result[#result + 1] = "preload[\"" .. file:gsub("%.lua$", ""):gsub("/", ".") .. "\"] = "
		if link then
			assert(fs.exists(whole), "Cannot find " .. file)
			result[#result + 1] = "loadfile(\"" .. whole .. "\")\n"
		else
			local read = fs.open(whole, "r")
			local contents = read.readAll()
			read.close()

			result[#result + 1] = "function(...)\n" .. contents .. "\nend\n"
		end
	end

	result[#result + 1] = "return preload[\"" .. self.startup:gsub("%.lua$", ""):gsub("/", ".") .. "\"](...)"

	local outputFile = fs.open(fs.combine(env.CurrentDirectory, output), "w")
	outputFile.write(table.concat(result))
	outputFile.close()
end

function Runner.Runner:AsRequire(name, files, outputFile, taskDepends)
	return self:InjectTask(Task.Factory(name, taskDepends, function(task, env)
		files:AsRequire(env, outputFile, task)
	end, Task.OptionTask))
		:Description("Packages files together to allow require")
		:Produces(outputFile)
end

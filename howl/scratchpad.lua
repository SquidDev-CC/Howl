local utils = require "howl.lib.utils"
local dump = require "howl.lib.dump".dump
local printColor = require "howl.lib.colored".printColor

local parsePattern = utils.parsePattern
local createLookup = utils.createLookup

local tasks = {
	{
		name = "input",
		provides = createLookup { "foo.un.lua" },
	},

	{
		name = "output",
		requires = createLookup { "foo.min.lua" },
	},

	{
		name = "minify",
		maps = {
			{
				from = parsePattern("wild:*.lua", true),
				to = parsePattern("wild:*.min.lua")
			}
		},
	},

	{
		name = "licence",
		maps = {
			{
				from = parsePattern("wild:*.un.lua", true),
				to = parsePattern("wild:*.lua")
			}
		},
	},
}

for k, v in pairs(tasks) do
	tasks[v.name] = v
	if not v.maps then v.maps = {} end
	v.mapper = #v.maps > 0
	if not v.provides then v.provides = {} end
	if not v.requires then v.requires = {} end
end

local function matching(name)
	local out = {}

	for _, task in ipairs(tasks) do
		if task.provides[name] then
			out[#out + 1] = { task = task.name }
		end

		for _, mapping in ipairs(task.maps) do
			if mapping.to.Type == "Text" then
				if mapping.to.Text == name then
					out[#out + 1] = {
						task = task.name,
						mapping.from.Text,
						name
					}
				end
			else
				if name:find(mapping.to.Text) then
					out[#out + 1] = {
						task = task.name,
						name:gsub(mapping.to.Text, mapping.from.Text),
						name
					}
				end
			end
		end
	end

	return out
end

local function resolveTasks(...)
	local out = {}

	local queue = {}

	local depCache = {}
	local function addDep(dependency, depth)
		local hash = dependency.task .. "|"..table.concat(dependency, "|")

		local existing = depCache[hash]
		if existing then
			existing.depth = math.min(existing.depth, depth)
			return existing
		else
			dependency.depth = depth
			dependency.needed = {}
			dependency.solutions = {}
			dependency.name = dependency.task .. ": " .. table.concat(dependency, " \26 ")
			depCache[hash] = dependency
			queue[#queue + 1] = dependency
			return dependency
		end
	end

	local function addSolution(solution, dependency)
		local solution = addDep(solution, dependency.depth + 1)
		solution.needed[#solution.needed + 1] = dependency

		return solution
	end

	for i = 1, select('#', ...) do
		addDep({ task = select(i, ...)}, 1)
	end

	while #queue > 0 do
		local dependency = table.remove(queue, 1)
		local task = tasks[dependency.task]

		print("Task '" .. dependency.name)
		if #dependency.needed > 0 then
			print("  Needed for")
			for i = 1, #dependency.needed do
				printColor("lightGrey", "    " .. dependency.needed[i].name)
			end
		end

		if dependency.depth > 4 then
			printColor("red", "  Too deep")
		elseif #dependency.solutions > 0 or (#task.requires == 0 and not task.mapper) then
			printColor("green", "  Endpoint")
			out[#out + 1] = dependency

			for i = 1, #dependency.needed do
				local needed = dependency.needed[i]
				needed.solutions[#needed.solutions + 1] = dependency

				-- This should only happen once everything has happened
				if #needed.solutions == 1 then
					queue[#queue + 1] = needed
				end
			end
		else
			for i = 1, #task.requires do
				local requirement = task.requires[i]
				print("  Depends on '" .. requirement .. "'")

				local matching = matching(requirement)
				for i = 1, #matching do
					local solution = addSolution(matching[i], dependency)

					printColor("yellow", "    Maybe: " .. solution.name)
				end
			end

			if task.mapper then
				local requirement = dependency[1]
				print("  Depends on '" .. requirement .. "'")

				local matching = matching(requirement)
				for i = 1, #matching do
					local solution = addSolution(matching[i], dependency)

					printColor("yellow", "    Maybe: " .. solution.name)
				end
			end
		end
	end

	return out
end

-- print(dump(tasks))
-- print("Resolved", dump(matching("foo.min.lua")))


local resolved = resolveTasks("output")
for i = 1, #resolved do
	print(resolved[i].name)
end

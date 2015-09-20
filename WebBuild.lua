local tries = 2
local branch = "master"
local task, repo

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
	elseif arg == "--tries" or arg == "-tries" then
		index = index + 1
		tries = tonumber(args[index])
		if tries == nil then
			error("Invalid number for tries: " .. args[index], 0)
		elseif tries <= 0 then
			error("Tries must be >= 1", 0)
		end
	elseif arg == "--task" or arg == "-task" or arg == "-t" then
		index = index + 1
		task = args[index]
	elseif not repo then
		repo = arg
	elseif not task then
		task = arg
	else
		error("Unexpected argument " .. arg)
	end

	index = index + 1
end

while repo == nil or repo == "" do
	write("Repo > ")
	repo = read()
end

local tree = download.getTree(repo, branch, tries)
if not tree then
	error("Could not fetch tree. Does the repo/branch exist?", 0)
end

--Prepare file download
local foundHowl = false
for _, file in ipairs(tree) do
	if file.path == "Howlfile.lua" or file.path == "Howlfile" and file.type == "blob" then
		foundHowl = true
		break
	end
end

if not foundHowl then
	error("Cannot find a Howlfile. It must be in the root of the project", 0)
end

local function fetch(tree)
	local errored = {}
	print("Downloading...")
	local function callback(success, path, file, count, total)
		if not success then
			errored[#errored + 1] = file

			local x, y = term.getCursorPos()
			term.setCursorPos(1, y)
			term.clearLine()
			printError("Cannot download " .. path)
		end

		local x, y = term.getCursorPos()
		term.setCursorPos(1, y)
		term.clearLine()
		write(("Downloading: %s/%s (%s%%)"):format(count, total, count / total * 100))
	end

	local download = download.download(repo, branch, tree, tries, callback)
	print()
	return download, errored
end

local files, errored = fetch(tree)
while #errored > 0 do
	write("Failed to download. Retry? [y/n]")
	if read():sub(1,1):lower() == "y" then
		local newFiles, newErrored = fetch(errored)
		errored = newErrored
		for k, v in pairs(newFiles) do files[k] = v end
	else
		error("Exiting", 0)
	end
end

local settings
do
	local howlSettings = files['.howl']
	if howlSettings then
		settings = textutils.unserialize(howlSettings)
		if settings == nil then error("Invalid format for .howl file", 0) end
	end
end

local howl
do
	local howlBin = settings and settings.howl or "http://pastebin.com/raw.php?i=uHRTm9hp"
	local handle = http.get(howlBin)
	if not handle then error("Cannot find Howl at " .. howlBin, 0) end

	howl = handle.readAll()
	handle.close()
end

local env = vfs(shell.dir(), files)

local howlFunc = assert(load(howl, "Howl", nil, setmetatable(env, { __index = _ENV})))

local function tokenise(...)
	local line = table.concat({ ... }, " ")
	local words = {}
	local bQuoted = false
	for match in string.gmatch(line .. "\"", "(.-)\"") do
		if bQuoted then
			words[#words + 1] = match
		else
			for m in string.gmatch( match, "[^ \t]+" ) do
				words[#words + 1] = m
			end
		end
		bQuoted = not bQuoted
	end
	return words
end
local args
if task then
	args = {task}
else
	term.write("Task > ")
	args = tokenise(read())
end
while true do
	local success, result = pcall(howlFunc, unpack(args))
	if not success then
		print("Running task failed:")
		printError(result)
	end

	term.write("Task > ")
	args = tokenise(read())
	if #args == 0 then break end
end

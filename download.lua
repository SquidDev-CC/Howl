local json = require "json"

--- Attempt to download a file listing
-- @tparam string repo The name of the repo
-- @tparam string branch The name of the branch
-- @tparam int tries Number of times to attempt to download
-- @treturn table? Tree of files
local function getTree(repo, branch, tries)
	local path = 'https://api.github.com/repos/'..repo..'/git/trees/'..branch..'?recursive=1'
	for i = 1, tries do
		local result = json(path)
		if result and result.tree then
			return result.tree
		end
	end

	return nil
end

--- Download individual files
-- @tparam string repo The name of the repo
-- @tparam string branch The name of the branch
-- @tparam table The list of files to download
-- @tparam int tries Number of times to attempt to download
-- @tparam (success:boolean, path:string, file: table, count:int, total:int)->nil callback Function to call after a download has finished
local function download(repo, branch, tree, tries, callback)
	local getRaw = 'https://raw.github.com/'..repo..'/'..branch..'/'
	local files = {}

	local count = 0
	local total = 0

	-- Download a file and store it in the tree
	local function download(file)
		local path = file.path
		local contents

		-- Attempt to download the file
		for i = 1, tries do
			local url = (getRaw .. path):gsub(' ','%%20')
			local f = http.get(url)

			if f then
				count = count + 1
				files[path] = f.readAll()
				callback(true, path, file, count, total)
				return
			end
		end

		callback(false, path, file, count, total)
	end

	local callbacks = {}

	for _, file in ipairs(tree) do
		if file.type == 'tree' then
			files[file.path] = true
		else
			total = total + 1
			callbacks[total] = function() download(file) end
		end
	end

	parallel.waitForAll(unpack(callbacks))
	return files
end

return {
	getTree = getTree,
	download = download
}

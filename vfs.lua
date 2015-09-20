local fs = fs

local matches = {
	["^"] = "%^",
	["$"] = "%$",
	["("] = "%(",
	[")"] = "%)",
	["%"] = "%%",
	["."] = "%.",
	["["] = "%[",
	["]"] = "%]",
	["*"] = "%*",
	["+"] = "%+",
	["-"] = "%-",
	["?"] = "%?",
	["\0"] = "%z",
}

--- Escape a string for using in a pattern
-- @tparam string pattern The string to escape
-- @treturn string The escaped pattern
local function escapePattern(pattern)
	return (pattern:gsub(".", matches))
end

local function resolveLocal(root, path)
	path = fs.combine(path, "")
	if path == root or path:sub(1, #root + 1) == root .. "/" then
		return path:sub(#root + 2)
	end

	return nil
end

--[[
Emulates a basic file system.
This doesn't have to be too advanced as it is only for Howl's use

The files is a list of paths to file contents, or true if the file
is a directory. Each file must start with the "/"

TODO: Override IO
]]
return function(root, files)
	-- Emulated filesystem (partially based of Oeed's)
	local env
	env = {
		fs = {
			list = function(path)
				local list = fs.isDir(path) and fs.list(path) or {}

				path = resolveLocal(root, path)
				if path ~= nil then
					local pattern = "^" .. escapePattern(path)
					if path ~= "" then pattern = pattern .. '/' end
					pattern = pattern .. '([^/]+)$'

					for file, _ in pairs(files) do
						local name = file:match(pattern)
						print(name, " ", file, " ", pattern)
						if name then list[#list + 1] = name end
					end
				end

				return list
			end,

			exists = function(path)
				if fs.exists(path) then
					return true
				else
					path = resolveLocal(root, path)
					return path ~= nil and files[fs.combine(path, '')] ~= nil
				end
			end,

			isDir = function(path)
				if fs.isDir(path) then
					return true
				else
					path = resolveLocal(root, path)
					return path ~= nil and files[fs.combine(path, '')] == true
				end
			end,

			isReadOnly = function(path)
				if fs.exists(path) then
					return fs.isReadOnly(path)
				else
					return false
				end
			end,

			getName = fs.getName,
			getDir = fs.getDir,
			getSize = fs.getSize,
			getFreespace = fs.getFreespace,
			makeDir = fs.makeDir,
			delete = fs.delete,
			combine = fs.combine,

			-- TODO: This should be implemented
			move = fs.move,
			copy = fs.copy,

			open = function(path, mode)
				if fs.exists(path) then
					return fs.open(path, mode)
				else
					path = resolveLocal(root, path)
					if path and type(files[subPath]) == 'string' then
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
					end
				end

				return fs.open(path, mode)
			end
		},

		loadfile = function(name)
			local file = env.fs.open(name, "r")
			if file then
				local func, err = loadstring(file.readAll(), fs.getName(name))
				file.close()
				return func, err
			end
			return nil, "File not found: "..name
		end,

		dofile = function(name)
			local file, e = env.loadfile(name)
			if file then
				setfenv(file, getfenv(2))
				return file()
			else
				error(e, 2)
			end
		end
	}
	env._G = env
	return env
end

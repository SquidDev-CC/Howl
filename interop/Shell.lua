-- Emulates the bits I use of the shell API
-- @module interop.Shell

require('pl')

local function getCurrent()
	local current
	if arg then current = arg[0] end
	if not current then current = debug.getinfo(1).short_source end
	if not current then return path.currentdir() end

	return path.normpath(path.join(path.currentdir(), current))
end

return {
	dir = path.currentdir,
	getRunningProgram = getCurrent,
}
--- Various helper methods
-- @module howl.lib.helpers

local refreshYield, dir
if fs then
	local push, pull = os.queueEvent, coroutine.yield

	function refreshYield()
		push("sleep")
		if pull() == "terminate" then error("Terminated") end
	end

	dir = shell.dir
else
	refreshYield = function() end
	dir = require"lfs".currentdir
end

return {
	refreshYield = refreshYield,
	dir = dir,
}

-- Emulates the bits I use of the shell API
-- @module interop.Shell

local push, pull = os.queueEvent, coroutine.yield

local function refreshYield()
	push("sleep")
	if pull() == "terminate" then error("Terminated") end
end

return {
	dir = shell.dir,
	refreshYield = refreshYield,
	serialize = textutils.serialize,
}

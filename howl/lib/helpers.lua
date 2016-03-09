local refreshYield
if fs then
	local push, pull = os.queueEvent, coroutine.yield

	local function refreshYield()
		push("sleep")
		if pull() == "terminate" then error("Terminated") end
	end
else
	refreshYield = function() end
end

return {
	refreshYield = refreshYield,
}

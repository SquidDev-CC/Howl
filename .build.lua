local func, msg = loadfile("bootstrap.lua", _ENV)
if not func then
	howlci.status("fail", "Cannot load boostrapper: " .. (msg or "<no msg>"))
	return
end

local ok, msg = pcall(func, "-v")
if not ok then
	howlci.status("fail", "Failed running task: " .. (msg or "<no msg>"))
else
	howlci.status("ok", "Everything built correctly!")
end

sleep(2)
howlci.close()

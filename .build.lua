if _HOST then howlci.log("info", "Host: " .. _HOST) end
if _CC_VERSION then howlci.log("info", "CC Version" .. _CC_VERSION) end
if _MC_VERSION then howlci.log("info", "MC Version" .. _MC_VERSION) end
if _LUAJ_VERSION then howlci.log("info", "LuaJ Version " .. _LUAJ_VERSION) end

local handle = fs.open(".howl/settings.lua", "w")
handle.write('{githubKey="not-set"}')
handle.close()

local func, msg = loadfile("bootstrap.lua", _ENV)
if not func then
	howlci.status("fail", "Cannot load bootstrapper: " .. (msg or "<no msg>"))
	return
end

local ok, msg = pcall(func, "-v", "build")
if not ok then
	howlci.status("fail", "Failed running task: " .. (msg or "<no msg>"))
else
	howlci.status("ok", "Everything built correctly!")
end

sleep(2)
howlci.close()

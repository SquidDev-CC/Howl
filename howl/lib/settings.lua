local currentSettings = {
}

if fs.exists(".howl.settings") then
	local handle = fs.open(".howl.settings", "r")
	local contents = handle.readAll()
	handle.close()

	for k, v in pairs(textutils.unserialize(contents)) do
		currentSettings[k] = v
	end
end

if settings then
	if fs.exists(".settings") then settings.load(".settings") end

	for k, v in pairs(currentSettings) do
		currentSettings[k] = settings.get("howl." .. k, v)
	end
end

return currentSettings

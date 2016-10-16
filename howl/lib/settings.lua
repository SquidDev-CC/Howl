local platform = require "howl.platform"
local fs = platform.fs
local dump = require "howl.lib.dump"

local currentSettings = {
}

if fs.exists(".howl/settings.lua") then
	local contents = fs.read(".howl/settings.lua")

	for k, v in pairs(dump.unserialise(contents)) do
		currentSettings[k] = v
	end
end

-- Things have to be defined in currentSettings for this to work. We need to improve this.
for k, v in pairs(currentSettings) do
	currentSettings[k] = platform.os.getEnv("howl." .. k, v)
end

return currentSettings

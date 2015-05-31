--- CC globals that aren't native
-- @module interop.Globals

write = io.write
printError = function(...)
	term.setTextColor(colors.red)
	print(...)
	term.setTextColor(colors.white)
end

-- Insert some basic functions
function os.queueEvent() end
function os.pullEvent() end
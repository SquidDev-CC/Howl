--- The native loader for platforms
-- @module howl.platform

if fs and term then
	return require "howl.platform.cc"
else
	return require "howl.platform.native"
end

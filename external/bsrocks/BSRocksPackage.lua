--- Basic interaction with Blue-Shiny-Rocks
-- @classmod howl.modules.bsrocks.BSRocksPackage

local fs = require "howl.platform".fs

local Package = require "howl.packages.Package"

local BSRocksPackage = Package:subclass(...)
	:addOptions { "package", "version" }

--- Setup the dependency, checking if it cannot be resolved
function BSRocksPackage:setup(runner)
	if not self.options.package then
		self.context.logger:error("BSRocks module must specify a package name")
	end
end

function BSRocksPackage:getName()
	return self.options.package
end

function BSRocksPackage:files(previous)
	if previous == nil then return {} end

	local brequire = self.context:getModuleData("blue-shiny-rocks").getRequire()
	if not brequire then return {} end

	local installDir = brequire "bsrocks.lib.settings".installDirectory

	local files = {}
	for _, file in pairs(previous.files) do
		if file:sub(1, 4) == "bin/" then
			files[file] = fs.combine(installDir, file .. ".lua")
		else
			files[file] = fs.combine(installDir, fs.combine("lib", file))
		end
	end

	return files
end

function BSRocksPackage:require(previous, refresh)
	local package = self.options.package
	local version = self.options.version

	local brequire = self.context:getModuleData("blue-shiny-rocks").getRequire()
	if not brequire then return previous end

	local install = brequire "bsrocks.rocks.install"
	local rockspec = brequire "bsrocks.rocks.rockspec"

	local rock = install.getInstalled()[self.options.package]
	if not rock then
		install.install(self.options.package)
		rock = install.getInstalled()[self.options.package]
	end

	return { files = rockspec.extractFiles(rock) }
end

return BSRocksPackage

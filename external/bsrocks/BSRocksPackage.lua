--- Basic interaction with Blue-Shiny-Rocks
-- @classmod howl.modules.bsrocks.BSRocksPackage

local fs = require "howl.platform".fs

local Package = require "howl.packages.Package"

local BSRocksPackage = Package:subclass(...)
	:addOptions { "package", "version" }

--- Setup this package, assuring all config options are valid
function BSRocksPackage:setup()
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

	local files = { }
	if previous.modules then
		local moduleDir = fs.combine(installDir, "lib")
		for module, file in pairs(previous.modules) do
			files[file] = fs.combine(moduleDir, module:gsub("%.", "/") .. ".lua")
		end
	end

	-- Extract install locations
	if previous.install then
		for name, install in pairs(previous.install) do
			local dir = fs.combine(installDir, name)
			for name, file in pairs(install) do
				if type(name) == "number" and name >= 1 and name <= #install then
					name = file
				end
				files[file] = fs.combine(dir, name .. ".lua")
			end
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

	local rock = install.getInstalled()[self.options.package]
	if not rock then
		install.install(self.options.package)
		rock = install.getInstalled()[self.options.package]
	end

	local build = rock.build
	return {
		modules = build and build.modules,
		install = build and build.install,
	}
end

return BSRocksPackage

--- A basic logger module
-- @classmod howl.lib.Logger
-- @pragma nostrip
-- @tfield bool isVerbose If verbose output should be printed
-- @tfield bool withMeta Display the metatable when dumping

--- Create a new logger
-- @tparam[opt=false] bool verbose Print verbose output
-- @tparam[opt=false] bool meta Display the metatable when dumping
-- @treturn Logger The created logger
-- @function Logger

--- Create a new logger
-- @tparam[opt=false] bool verbose Print verbose output
-- @tparam[opt=false] bool meta Display the metatable when dumping
-- @treturn Logger The created logger
-- @function Logger

return require("howl.lib.platform").Logger

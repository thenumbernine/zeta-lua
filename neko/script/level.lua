local NekoLevel = require 'base.script.level':subbehavior(
	--require 'base.script.behavior.level_temperature'	-- not using it yet and TODO how come in the wasm lua5.4+libffi version this returns a string?
)

-- only spawn the player ... and whatever's close to him
-- then, as the player moves, spawn things just out of his screen
function NekoLevel:initialSpawn() end

return NekoLevel

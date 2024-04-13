local NekoLevel = require 'base.script.level':subbehavior(
	require 'base.script.behavior.level_temperature'
)

-- only spawn the player ... and whatever's close to him
-- then, as the player moves, spawn things just out of his screen
function NekoLevel:initialSpawn() end

return NekoLevel

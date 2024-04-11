local Game = require 'base.script.singleton.class.game'
local behaviors = require 'base.script.behaviors'

local NekoGame = behaviors(Game
--	, require 'base.script.behavior.postfbo'
)

NekoGame.name = 'NekoGame'
NekoGame.gravity = -50
NekoGame.maxVel = 1000
NekoGame.maxFallVel = 20
--NekoGame.viewSize = 12	-- half width of the screen, in tiles

-- override respawn, don't respawn
function NekoGame:respawn(spawnInfo) end

function NekoGame:getPlayerClass()
	return require 'neko.script.obj.neko'
end

return NekoGame

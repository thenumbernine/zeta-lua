local Game = require 'base.script.singleton.class.game'
local behaviors = require 'base.script.behaviors'

local NekoGame = behaviors(Game
--	, require 'base.script.behavior.postfbo'
)

NekoGame.name = 'NekoGame'
NekoGame.gravity = -50
NekoGame.maxVel = 1000
NekoGame.maxFallVel = 20

-- half width of the screen, in tiles
--NekoGame.viewSize = 8		-- = 16 wide = snes / super metroid
--NekoGame.viewSize = 10	-- = 20 wide = cave story
--NekoGame.viewSize = 12	-- = 24 wide
-- default is 16 <=> 32 wide

-- override respawn, don't respawn
function NekoGame:respawn(spawnInfo) end

function NekoGame:getPlayerClass()
	return require 'neko.script.obj.neko'
end

return NekoGame

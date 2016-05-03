local class = require 'ext.class'
local Game = require 'base.script.singleton.class.game'

local ZetaGame = class(Game)
ZetaGame.name = 'ZetaGame'
ZetaGame.gravity = -40
--ZetaGame.maxFallVel = 16	-- slows shots as well ... hmm ...

-- override respawn, don't respawn
function ZetaGame:respawn(spawnInfo) end

-- if enough games are just going to override this ...
-- maybe I should just put it in a root-level require'd file? playerclass.lua
function ZetaGame:getPlayerClass()
	return require 'zeta.script.obj.hero'
end

return ZetaGame

local Game = require 'base.script.singleton.class.game'

local ZetaGame = behaviors(Game
--	, require 'base.script.behavior.postfbo'
)

ZetaGame.name = 'ZetaGame'
ZetaGame.gravity = -50
ZetaGame.maxVel = 1000
ZetaGame.maxFallVel = 20

function ZetaGame:resetObjects(...)
	ZetaGame.super.resetObjects(self, ...)
	self.bosses = table()
end

function ZetaGame:update(...)
	ZetaGame.super.update(self, ...)

	for i=#self.bosses,1,-1 do
		if self.bosses[i].remove then
			self.bosses:remove(i)
		end
	end
end

-- override respawn, don't respawn
function ZetaGame:respawn(spawnInfo) end

-- if enough games are just going to override this ...
-- maybe I should just put it in a root-level require'd file? playerclass.lua
function ZetaGame:getPlayerClass()
	return require 'zeta.script.obj.hero'
end

return ZetaGame

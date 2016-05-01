local class = require 'ext.class'
local Game = require 'base.script.singleton.class.game'

local MetroidGame = class(Game)
MetroidGame.name = 'MetroidGame'
MetroidGame.gravity = -50
MetroidGame.maxFallVel = 16

-- if enough games are just going to override this ...
-- maybe I should just put it in a root-level require'd file? playerclass.lua
function MetroidGame:getPlayerClass()
	return require 'metroid.script.obj.samus'
end

return MetroidGame
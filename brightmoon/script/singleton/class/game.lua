local class = require 'ext.class'
local Game = require 'base.script.singleton.class.game'
require 'ext.math'

local BrightMoonGame = class(Game)
BrightMoonGame.name = 'BrightMoonGame'
BrightMoonGame.gravity = 0
BrightMoonGame.maxFallVel = math.inf

-- if enough games are just going to override this ...
-- maybe I should just put it in a root-level require'd file? playerclass.lua
function BrightMoonGame:getPlayerClass()
	return require 'brightmoon.script.obj.player'
end

return BrightMoonGame
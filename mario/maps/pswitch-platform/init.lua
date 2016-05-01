local game = require 'base.script.singleton.game'
local PSwitch = require 'mario.script.obj.p-switch'
require 'base.script.util'	-- setTimeout...

-- TURN YOUR PSWITCH INTO A MOVING PLATFORM!
local _, pswitch = game.objs:find(nil, function(obj) return getmetatable(obj) == PSwitch end)
pswitch.canCarry = false
pswitch.pushPriority = math.huge	-- no one can push me!
pswitch.resetDuration = 5
pswitch.floodStepDuration = .3
pswitch.playerBounce = function(self, player)
	if PSwitch.playerBounce(self, player) == false then return false end
	setTimeout(2, PSwitch.floodFill, self, self.pos[1], self.pos[2])
end

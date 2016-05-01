local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

--[[
TODO:
- jump on a spring, even if holding 'y', and you do the spring routine (no pick up from landing on top)
- land on spring, fix player and do spring animation, then do small/big bounce based on whether the jump button is held down
--]]

local Springboard = class(GameObject)
Springboard.sprite = 'springboard'
Springboard.canCarry = true

--[[
TODO
playerBounce is the wrong function to use.
it determines whether or not a player can do an ordinary-jump on an object
we want something that executes upon player jump-and-hold
and a similar callback to execute upon player spinjump-and-hold
-- ]]
function Springboard:playerBounce(other)
	if other == self.kickedBy and self.kickHandicapTime >= game.time then return end
	
	if other.inputJump then
		other.vel[2] = 60
	else
		other.vel[2] = 20
	end
	
	self:playSound('springboard')
	return false	-- don't "bounce" -- no sfx, no reassigning the y-vel
end

function Springboard:canBeHeldBy(player)
	local dx = player.pos[1] - self.pos[1]
	local dy = player.pos[2] - self.pos[2]
	local adx, ady = math.abs(dx), math.abs(dy)
	if dy > 0 and ady > adx then return false end
	return true
end

return Springboard
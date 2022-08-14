local game = require 'base.script.singleton.game'
local behaviors = require 'base.script.behaviors'

--[[
TODO:
- jump on a spring, even if holding 'y', and you do the spring routine (no pick up from landing on top)
- land on spring, fix player and do spring animation, then do small/big bounce based on whether the jump button is held down
--]]

local Springboard = behaviors(require 'base.script.obj.object',
	require 'mario.script.behavior.kickable')
Springboard.sprite = 'springboard'
-- SOLID_NO means things fall through it, 
-- including the player when the player goes to jump on it ...
-- but SOLID_YES means it blocks things, including other shells and springboards, etc
--Springboard.solidFlags = Springboard.SOLID_NO

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

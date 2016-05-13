local class = require 'ext.class'
local Geemer = require 'zeta.script.obj.geemer'
local box2 = require 'vec.box2'
local game = require 'base.script.singleton.game'

local BossGeemer = class(Geemer)
BossGeemer.maxHealth = 20
BossGeemer.bbox = box2(-.9, 0, .9, 1.8)
BossGeemer.drawScale = {2,2}
-- todo - some parabola math to make sure they jump right on the player
BossGeemer.jumpVel = 20
BossGeemer.runVel = 10
BossGeemer.attackDist = 10

function BossGeemer:calcVelForJump(delta)
	--[[ delta is the vector from the geemer to the player
	delta[1] = vel[1]*t
	delta[2] = vel[2]*t + .5*game.gravity*t^2
	--]]
	local t = 1 -- desired time til impact
	self.vel[1] = delta[1] / t
	self.vel[2] = delta[2] / t - .5 * game.gravity * t
end

return BossGeemer

local class = require 'ext.class'
local Geemer = require 'zeta.script.obj.geemer'
local box2 = require 'vec.box2'
local game = require 'base.script.singleton.game'
local GeemerChunk = require 'zeta.script.obj.geemerchunk'

local BossGeemer = class(Geemer)
BossGeemer.maxHealth = 20
BossGeemer.bbox = box2(-.9, 0, .9, 1.8)
BossGeemer.drawScale = {2,2}
-- todo - some parabola math to make sure they jump right on the player
BossGeemer.jumpVel = 20
BossGeemer.runVel = 10
BossGeemer.attackDist = 10
BossGeemer.spawnAtFirst = true		-- dont' remove the boss before the boss is dead

BossGeemer.itemDrops = nil
function BossGeemer:calcVelForJump(delta)
	--[[ delta is the vector from the geemer to the player
	delta[1] = vel[1]*t
	delta[2] = vel[2]*t + .5*game.gravity*t^2
	--]]
	local t = 1 -- desired time til impact
	self.vel[1] = delta[1] / t
	self.vel[2] = delta[2] / t - .5 * game.gravity * t
end

function BossGeemer:die(damage, attacker, inflicter, side)
	BossGeemer.super.die(self, attacker, inflicter, side)
	for i=1,4 do
		GeemerChunk.makeAt{
			pos = self.pos,
			-- should be inflicter.pos, but the shot needs to stop at the surface for that to happen
			dir = (self.pos - attacker.pos):normalize(),
			color = self.color,
		}
	end
end

return BossGeemer

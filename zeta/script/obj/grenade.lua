local bit = require 'bit'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local MissileBlast = require 'zeta.script.obj.missileblast'
local Puff = require 'zeta.script.obj.puff'
local game = require 'base.script.singleton.game'
local behaviors = require 'base.script.behaviors'
local Grenade = behaviors(require 'base.script.obj.object',
	require 'zeta.script.behavior.takesdamage')
Grenade.bbox = box2(-.1, 0, .1, .2)
Grenade.sprite = 'grenade'
Grenade.maxHealth = 1
Grenade.damage = 3
Grenade.splashDamage = 3
Grenade.rotCenter = {.5, .5}

function Grenade:init(...)
	Grenade.super.init(self, ...)
	
	self.vel[1] = self.vel[1] * (math.random() * .2 + .9)
	self.vel[2] = self.vel[2] * (math.random() * .2 + .9)
	self.shooter:hasKicked(self)
	self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
	self.rotation = (math.random()*2-1) * 360
	self.detonateTime = game.time + 2.9 + math.random() * .2
end

function Grenade:update(dt)
	Grenade.super.update(self, dt)
	if not self.onground then
		self.angle = self.angle + dt * self.rotation
	end
	if game.time >= self.detonateTime then
		self:blast()
	end
end

Grenade.solidFlags = Grenade.SOLID_GRENADE
Grenade.touchFlags = Grenade.SOLID_WORLD 
					+ Grenade.SOLID_YES 
					+ Grenade.SOLID_NO 
					+ Grenade.SOLID_GRENADE
Grenade.blockFlags = Grenade.SOLID_WORLD

function Grenade:touchTile(tile, side, normal)
	if tile and tile.solid then
		self:bounceOff(normal)
	end
end
function Grenade:touch(other, side)
	if self.remove then return true end
	if self.kickedBy == other and self.kickHandicapTime >= game.time then
		return true
	end
-- [[ detonate on impact?
	if other.takeDamage then
		self.detonateTime = game.time
	end
--]]
	if bit.band(other.solidFlags, self.blockFlags) == 0 then
		return true
	end
	-- bounce
	local normal = dirs[oppositeSide[side]]
	self:bounceOff(normal)
end

function Grenade:hit()
	self.detonateTime = math.min(self.detonateTime, game.time + math.random() * .5)
end
Grenade.deathSound = nil
Grenade.removeOnDie = false
function Grenade:die(...)
	self.detonateTime = math.min(self.detonateTime, game.time + math.random() * .5)
	-- call any onDie callbacks
	Grenade.super.die(self, ...)
end

Grenade.restitution = .5
function Grenade:bounceOff(normal)
	if self.vel[1] == 0 and self.vel[2] == 0 then
		self.rotation = 0
		return
	end
	normal = vec2(table.unpack(normal)):normalize()
	local vx, vy = self.vel:unpack()
	local vDotN = vx * normal[1] + vy * normal[2]
	if vDotN >= 0 then return end	-- don't bounce if we're leaving the wall
	local r = vDotN * (1 + self.restitution)
	vx = vx - normal[1] * r 
	vy = vy - normal[2] * r 
	self.rotation = (math.random()*2-1) * 360
	self.vel[1] = vx
	self.vel[2] = vy
	-- TODO transfer force into the object we hit?
	-- esp if it's another grenade?
	self.pos[1] = self.lastpos[1]
	self.pos[2] = self.lastpos[2]
end

function Grenade:blast(alreadyHit)
	if self.remove then return end

	Puff.puffAt(self.pos[1], self.pos[2]-.5)
	MissileBlast{pos={self.pos[1], self.pos[2]-.5}}
	self:playSound('explode2')
	self.remove = true

	-- splash damage 
	-- TODO ignore objects just hit by damage?
	local force = 10
	for _,other in ipairs(game.objs) do
		if other ~= self then
			local delta = other.pos - self.pos
			-- TODO and traceline ...
			local lenSq = delta:lenSq()
			if lenSq < 2*2 then
				if other.takeDamage and other ~= alreadyHit then
					other:takeDamage(self.splashDamage, self.shooter, self, side)
				end
				-- TODO ... only solid? (should grenades be solid?) only takeDamage (should grenades take damage?)
				if Grenade:isa(other) then
					other.vel = other.vel + delta * (force / (lenSq + 1))
					other.vel[2] = other.vel[2] + 5
					other.detonateTime = math.min(other.detonateTime, game.time + math.random() * .8 + .2)
				end
			end
		end
	end
end

return Grenade

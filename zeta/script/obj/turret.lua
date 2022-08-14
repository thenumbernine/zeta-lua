local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local Enemy = require 'zeta.script.obj.enemy'
local MissileBlast = require 'zeta.script.obj.missileblast'
local game = require 'base.script.singleton.game'
local dirs = require 'base.script.dirs'

local Turret = class(Enemy)

Turret.sprite = 'turret-body'
Turret.maxHealth = 3
Turret.rotCenter = {.5, .5}
Turret.angle = 90
Turret.circuit = 'Main'

Turret.stuckAngle = 0
function Turret:init(...)
	Turret.super.init(self, ...)

	-- see if there's a block near us
	-- if so, stick to that block
	local level = game.level
	for side,dir in pairs(dirs) do
		local pos = self.pos + dir
		local tile = level:getTile(pos:unpack())
		if tile and tile.solid then
			self.stuckPos = pos
			self.stuckSide = side
			self.stuckAngle = math.deg(math.atan2(dir[2], dir[1])) + 90
			self.useGravity = false
			break
		end
	end
end

-- look for player
-- shoot at player
Turret.searchDist = 15
Turret.shootDist = 10
Turret.shootAngleThreshold = 30	-- degrees
Turret.rotationSpeed = 90 	-- degrees per second
function Turret:update(dt)
	Turret.super.update(self, dt)
	if self.health == 0 then return end
	
	local targetAngle
	if not game.session['defensesActive_'..self.circuit] then
		self.seq = 'idle'
		if self.angle ~= targetAngle then
			targetAngle = (self.stuckAngle + 90) % 360
		end
	else
		self.seq = nil
		local level = game.level
		
		-- TODO - flag for 'detected by turrets' ? 
		local bestDist, bestObj, bestDelta
		local Hero = require 'zeta.script.obj.hero'
		--local Geemer = require 'zeta.script.obj.geemer'
		--for obj in game:objsInRange(self.searchDist) do
		--for _,obj in ipairs(game.objs) do
		for _,obj in ipairs(game.players) do
			if Hero:isa(obj)
			--or Geemer:isa(obj)
			then
				local delta = obj.pos - self.pos
				if delta:length() < self.searchDist then
					local blocked
					
					local dist = math.max(math.abs(delta[1]), math.abs(delta[2]))
					for i=0,dist-1 do
						local f = (i+.5)/dist
						local x = self.pos[1] + f * delta[1]
						local y = self.pos[2] + f * delta[2] + .5
						local tile = game.level:getTile(x,y)
						if tile and tile.solid then
							blocked = true
							break
						end
					end

					if not blocked then
						if not bestDist or dist < bestDist then
							bestDist = dist
							bestObj = obj
							bestDelta = delta
						end
					end
				end
			end
		end
		if bestObj then
			targetAngle = math.deg(math.atan2(bestDelta[2], bestDelta[1]))
			if bestDelta:length() < self.shootDist
			and math.abs(self.angle - targetAngle) < self.shootAngleThreshold then
				self:shoot()
			end
		end
	end
	if targetAngle then
		-- choose an angle within 180' of the park angle, so you rotate the right way
		local oppositeAngle = targetAngle - 180
		self.angle = ((self.angle - oppositeAngle) % 360) + oppositeAngle
		local rot = self.rotationSpeed * dt
		local deltaAngle = targetAngle - self.angle
		if math.abs(deltaAngle) < rot then
			self.angle = targetAngle
		else
			self.angle = self.angle + (deltaAngle < 0 and -1 or 1) * rot
		end
	end
end

function Turret:hit(damage, attacker, inflicter, side)
	self:playSound('explode1')
end

Turret.nextShootTime = -1
Turret.shotDelay = .6
Turret.ammo = 3	-- three shots then refill
Turret.ammoRefillDelay = 2
Turret.shotSpeed = 10
function Turret:shoot()
	if self.health == 0 then return end
	if self.nextShootTime >= game.time then return end
	self.ammo = self.ammo - 1
	if self.ammo <= 0 then
		self.nextShootTime = game.time + self.ammoRefillDelay 
		self.ammo = nil	-- default
	else
		self.nextShootTime = game.time + self.shotDelay
	end

	local Blaster = require 'zeta.script.obj.blaster'
	self:playSound(Blaster.shotSound)
	local theta = math.rad(self.angle)
	local dir = vec2(math.cos(theta), math.sin(theta))
	local BlasterShot = require 'zeta.script.obj.blastershot'
	BlasterShot{
		shooter = self,
		pos = self.pos,
		vel = dir * self.shotSpeed,
	}
end

Turret.itemDrops = {
	['zeta.script.obj.healthitem'] = .1,
	['zeta.script.obj.cellitem'] = .1,
	['zeta.script.obj.grenadeitem'] = .1,
	['zeta.script.obj.missileitem'] = .1,
}

-- TODO missileblast object, use it here, grenades, and missiles
function Turret:die()
	-- item drops
	Turret.super.die(self, damage, attacker, inflicter, side)
	MissileBlast{pos={self.pos[1],self.pos[2]-.5}}
end

function Turret:draw(R, viewBBox, ...)
	-- draw base underneath
	if self.health > 0 then
		local angle = self.angle
		local seq = self.seq
		self.sprite = 'turret-base'
		self.seq = nil
		self.angle = self.stuckAngle
		Turret.super.draw(self, R, viewBBox, ...)
		self.sprite = nil
		self.seq = seq
		self.angle = angle
	end
	Turret.super.draw(self, R, viewBBox, ...)
end

return Turret

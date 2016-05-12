local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local takesDamageBehavior = require 'zeta.script.obj.takesdamage'
local game = require 'base.script.singleton.game'

local Turret = class(takesDamageBehavior(Object))
Turret.sprite = 'turret-body'
Turret.solid = false
Turret.maxHealth = 3
Turret.rotCenter = {.5, .5}
Turret.angle = 90
Turret.deactivated = false

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
function Turret:update(dt)
	Turret.super.update(self, dt)
	if self.health == 0 then return end
	
	local targetAngle
	if self.deactivated then
		self.seq = 'idle'
		if self.angle ~= targetAngle then
			targetAngle = (self.stuckAngle + 90) % 360
		end
	else
		for _,player in ipairs(game.players) do
			local delta = player.pos - self.pos
			if delta:length() < 8 then
				targetAngle = math.deg(math.atan2(delta[2], delta[1]))
				if math.abs(self.angle - targetAngle) < 30 then
					self:shootAt(player)
				end
				break
			end
		end
	end
	if targetAngle then
		-- choose an angle within 180' of the park angle, so you rotate the right way
		local oppositeAngle = targetAngle - 180
		self.angle = ((self.angle - oppositeAngle) % 360) + oppositeAngle
		local rot = 180 * dt	-- rotation amount
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

local BlasterItem = require 'zeta.script.obj.blaster'
local BlasterShot = BlasterItem.shotClass
Turret.nextShootTime = -1
Turret.shotDelay = .5
Turret.ammo = 3	-- three shots then refill
Turret.ammoRefillDelay = 2
function Turret:shootAt(player)
	if self.health == 0 then return end
	if self.nextShootTime >= game.time then return end
	self.ammo = self.ammo - 1
	if self.ammo <= 0 then
		self.nextShootTime = game.time + self.ammoRefillDelay 
		self.ammo = nil	-- default
	else
		self.nextShootTime = game.time + self.shotDelay
	end

	self:playSound(BlasterItem.shotSound)
	local theta = math.rad(self.angle)
	local dir = vec2(math.cos(theta), math.sin(theta))
	BlasterShot{
		shooter = self,
		pos = self.pos,
		vel = dir * BlasterItem.shotSpeed,
	}
end

-- TODO missileblast object, use it here, grenades, and missiles
function Turret:die()
	self.sprite = 'missileblast'
	self.seq = nil
	self.seqStartTime = game.time
	self.removeTime = game.time + .75
	self.pos[2] = self.pos[2] - 1
	self.angle = 0

	self.collidesWithWorld = false

	self:playSound('explode2')
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

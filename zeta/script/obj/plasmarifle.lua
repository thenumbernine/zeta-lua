-- shot object:

local PlasmaShot = (function()
	local class = require 'ext.class'
	local Object = require 'base.script.obj.object'
	local game = require 'base.script.singleton.game'
	local box2 = require 'vec.box2'

	local PlasmaShot = class(Object)
	PlasmaShot.bbox = box2(-.1, 0, .1, .2)
	PlasmaShot.sprite = 'plasma-shot'
	PlasmaShot.useGravity = false
	PlasmaShot.solid = false
	PlasmaShot.damage = 3
	PlasmaShot.rotCenter = {.5, .5}

	function PlasmaShot:init(...)
		PlasmaShot.super.init(self, ...)
		
		self.shooter:hasKicked(self)
		self.angle = self.shooter.weapon.angle
		self.drawMirror = self.shooter.weapon.drawMirror
		--setTimeout(.2, function() self.remove = true end)
	end

	function PlasmaShot:update(dt, ...)
		if self.collidesWithObjects then
			self.angle = game.time
		end
		PlasmaShot.super.update(self, dt, ...)
	end

	function PlasmaShot:touchTile(tile, side)
		-- generalize this for all projectiles
		-- TODO onHit?
		if tile.onHit then
			tile:onHit(self, side)
		end
		
		self:blast()
	end

	function PlasmaShot:pretouch(other, side)
		if self.remove then return end	-- only hit one object
		if other == self.shooter then return true end
		local Item = require 'zeta.script.obj.item'
		if other:isa(Item) then return end
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
		end
		if other.takeDamage or other.solid then
			self:blast()
			return
		end
		return true
	end

	PlasmaShot.solidFlags = PlasmaShot.SOLID_SHOT
	PlasmaShot.touchFlags = PlasmaShot.SOLID_WORLD + PlasmaShot.SOLID_YES + PlasmaShot.SOLID_NO
	PlasmaShot.blockFlags = PlasmaShot.SOLID_WORLD + PlasmaShot.SOLID_YES
	function PlasmaShot:touchTile_v2(tile, side)
		self:blast()
	end
	function PlasmaShot:touch_v2(other, side)
		if self.remove then return true end
		if other == self.shooter then return true end
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
		end
		if other.takeDamage then
			self:blast()
		end
		if bit.band(other.solidFlags, other.SOLID_NO) ~= 0 then return end
		return true
	end

	function PlasmaShot:blast()
		self.vel[1] = 0
		self.vel[2] = 0
		
		self.sprite = 'plasma-blast'
		self.seqStartTime = game.time
		self.pos[2] = self.pos[2] - .25
		self.angle = nil

		self.collidesWithWorld = false
		self.collidesWithObjects = false
		self.solidFlags = 0
		self.touchFlags = 0
		self.blockFlags = 0

		self.removeTime = game.time + 5/8
	end

	return PlasmaShot
end)()

-- world object

local PlasmaRifle = (function()
	local class = require 'ext.class'
	local Weapon = require 'zeta.script.obj.weapon'
	local game = require 'base.script.singleton.game'
	
	local PlasmaRifle = class(Weapon)
	PlasmaRifle.sprite = 'plasma-rifle'
	PlasmaRifle.shotDelay = .05
	PlasmaRifle.shotSpeed = 40
	PlasmaRifle.shotSound = 'shoot'
	PlasmaRifle.rapidFire = true
	PlasmaRifle.shotClass = PlasmaShot
	PlasmaRifle.drawOffsetStanding = {.5, .25}
	PlasmaRifle.rotCenter = {.25, .35}
	PlasmaRifle.shotOffset = {0, .45}
	
	PlasmaRifle.spreadAngle = 5
	function PlasmaRifle:getShotPosVel(player)
		local pos, vel = PlasmaRifle.super.getShotPosVel(self, player)
		local angle = (math.random() - .5) * self.spreadAngle
		local theta = math.rad(angle)
		local x, y = math.cos(theta), math.sin(theta)
		vel[1], vel[2] = x * vel[1] - y * vel[2], x * vel[2] + y * vel[1]
		return pos, vel
	end

	function PlasmaRifle:canShoot(player)
		if not PlasmaRifle.super.canShoot(self, player) then return end
		if player.ammoCells < 1 then return end
		player.ammoCells = player.ammoCells - 1
		player.nextRechargeCellsTime = game.time + .5 
		return true
	end


	return PlasmaRifle
end)()

return PlasmaRifle

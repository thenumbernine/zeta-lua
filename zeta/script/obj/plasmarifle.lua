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

	function PlasmaShot:init(args, ...)
		PlasmaShot.super.init(self, args, ...)
		
		self.shooter = args.shooter
		self:hasBeenKicked(args.shooter)
		
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
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
		end
		if other.takeDamage or other.solid then
			self:blast()
			return
		end
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
		
		self.removeTime = game.time + 5/8
	end

	return PlasmaShot
end)()

-- world object

local PlasmaRifleItem = (function()
	local class = require 'ext.class'
	local Weapon = require 'zeta.script.obj.weapon'
	local game = require 'base.script.singleton.game'
	
	local PlasmaRifleItem = class(Weapon)
	PlasmaRifleItem.sprite = 'plasma-rifle'
	PlasmaRifleItem.shotDelay = .05
	PlasmaRifleItem.shotSpeed = 40
	PlasmaRifleItem.shotSound = 'shoot'
	PlasmaRifleItem.rapidFire = true
	PlasmaRifleItem.shotClass = PlasmaShot
	PlasmaRifleItem.drawOffsetStanding = {.5, .25}
	PlasmaRifleItem.rotCenter = {.25, .35}
	PlasmaRifleItem.shotOffset = {0, .45}
	
	PlasmaRifleItem.spreadAngle = 5
	function PlasmaRifleItem:getShotPosVel(player)
		local pos, vel = PlasmaRifleItem.super.getShotPosVel(self, player)
		local angle = (math.random() - .5) * self.spreadAngle
		local theta = math.rad(angle)
		local x, y = math.cos(theta), math.sin(theta)
		vel[1], vel[2] = x * vel[1] - y * vel[2], x * vel[2] + y * vel[1]
		return pos, vel
	end
	
	return PlasmaRifleItem
end)()

return PlasmaRifleItem

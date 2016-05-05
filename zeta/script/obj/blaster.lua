-- shot object:

local BlasterShot = (function()
	local class = require 'ext.class'
	local Object = require 'base.script.obj.object'
	local game = require 'base.script.singleton.game'
	local box2 = require 'vec.box2'

	local BlasterShot = class(Object)
	BlasterShot.bbox = box2(-.1, 0, .1, .2)
	BlasterShot.sprite = 'blaster-shot'
	BlasterShot.useGravity = false
	BlasterShot.solid = false
	BlasterShot.speed = 35
	BlasterShot.damage = 1
	BlasterShot.rotCenter = {.5, .5}

	function BlasterShot:init(args, ...)
		args.vel = args.dir * self.speed
		BlasterShot.super.init(self, args, ...)
		
		self.shooter = args.shooter
		self:hasBeenKicked(args.shooter)
		self:playSound('shoot')
		
		--self.angle = self.shooter.weapon.angle
		--self.drawMirror = self.shooter.weapon.drawMirror
		self.angle = math.deg(math.atan2(args.dir[2], args.dir[1]))
		self.drawMirror = args.dir[1] < 0
		if self.drawMirror then self.angle = -self.angle end

		setTimeout(.2, function() self.remove = true end)
	end

	function BlasterShot:touchTile(tile, side)
		-- generalize this for all projectiles
		-- TODO onHit?
		if tile.onHit then
			tile:onHit(self, side)
		end
		
		self.vel[1] = 0
		self.vel[2] = 0
		self.collidesWithWorld = false
		self.collidesWithObjects = false
		self.remove = true
	end

	function BlasterShot:pretouch(other, side)
		if self.remove then return end	-- only hit one object
		if other == self.shooter then return true end
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
		end
		if other.takeDamage or other.solid then
			self.collidesWithWorld = false
			self.collidesWithObjects = false
			self.remove = true
			return
		end
		return true
	end

	return BlasterShot
end)()

-- world object

local BlasterItem = (function()
	local class = require 'ext.class'
	local Weapon = require 'zeta.script.obj.weapon'
	local game = require 'base.script.singleton.game'
	
	local BlasterItem = class(Weapon)
	BlasterItem.sprite = 'blaster'
	BlasterItem.shotDelay = .05
	BlasterItem.shotClass = BlasterShot

	return BlasterItem
end)()

return BlasterItem

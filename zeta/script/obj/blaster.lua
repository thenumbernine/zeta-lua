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
	BlasterShot.damage = 1
	BlasterShot.rotCenter = {.5, .5}

	function BlasterShot:init(...)
		BlasterShot.super.init(self, ...)
		
		--self.angle = self.shooter.weapon.angle
		--self.drawMirror = self.shooter.weapon.drawMirror
		self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
		self.drawMirror = self.vel[1] < 0
		if self.drawMirror then self.angle = -self.angle end

		self.removeTime = game.time + .2
	end

	BlasterShot.solidFlags = BlasterShot.SOLID_SHOT	
	BlasterShot.touchFlags = BlasterShot.SOLID_WORLD + BlasterShot.SOLID_YES + BlasterShot.SOLID_NO
	BlasterShot.blockFlags = BlasterShot.SOLID_WORLD + BlasterShot.SOLID_YES
	
	function BlasterShot:touchTile(tileType, side, plane, x, y)
		if tileType and tileType.name == 'blaster-break' then
			-- TODO level setter for current tile
			-- and maybe built-in smoothing?
			local level = game.level
			level.tileMap[(x-1)+level.size[1]*(y-1)] = 0
			level.fgTileMap[(x-1)+level.size[1]*(y-1)] = 0
		
			self:playSound'explode1'
			local Puff = require 'zeta.script.obj.puff'
			Puff.puffAt(x+.5, y-.5)
		end
		self.remove = true
	end
	
	function BlasterShot:touch(other, side)
		if self.remove then return true end
		if other == self.shooter then return true end	-- don't hit shooter
		if other.takeDamage then
			other:takeDamage(self.damage, self.shooter, self, side)
		end
		self.remove = true
	end

	return BlasterShot
end)()

-- world object

local Blaster = (function()
	local class = require 'ext.class'
	local Weapon = require 'zeta.script.obj.weapon'
	local game = require 'base.script.singleton.game'
	
	local Blaster = class(Weapon)
	Blaster.sprite = 'blaster'
	Blaster.shotDelay = .3
	Blaster.shotSpeed = 35
	Blaster.shotClass = BlasterShot
	Blaster.shotSound = 'shoot'

	--[[ if you want the blaster to use cells 
	function Blaster:canShoot(player)
		if not Blaster.super.canShoot(self, player) then return end
		if player.ammoCells < 1 then return end
		player.ammoCells = player.ammoCells - 1
		player.nextRechargeCellsTime = game.time + .5 
		return true
	end
	--]]

	return Blaster
end)()

return Blaster

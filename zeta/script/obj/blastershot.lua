local box2 = require 'vec.box2'
local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local BlasterShot = class(Object)
BlasterShot.bbox = box2(-.1, -.1, .1, .1)
BlasterShot.sprite = 'blaster-shot'
BlasterShot.useGravity = false
BlasterShot.damage = 1
BlasterShot.rotCenter = {.5, .5}
BlasterShot.drawCenter = {.5, .5}

function BlasterShot:init(...)
	BlasterShot.super.init(self, ...)
	
	--self.angle = self.shooter.weapon.angle
	--self.drawMirror = self.shooter.weapon.drawMirror
	self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
	self.drawMirror = self.vel[1] < 0
	if self.drawMirror then self.angle = -self.angle end

--	self.removeTime = game.time + .2
end

BlasterShot.solidFlags = BlasterShot.SOLID_SHOT
BlasterShot.touchFlags = bit.bor(BlasterShot.SOLID_WORLD, BlasterShot.SOLID_YES, BlasterShot.SOLID_NO)
BlasterShot.blockFlags = bit.bor(BlasterShot.SOLID_WORLD, BlasterShot.SOLID_YES)

function BlasterShot:touchTile(tileType, side, plane, x, y)
	if require 'zeta.script.tile.blasterbreak':isa(tileType) then
		game.level:clearTileAndBreak(x,y, self)
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

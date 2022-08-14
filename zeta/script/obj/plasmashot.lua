local bit = require 'bit'
local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local PlasmaShot = class(Object)

PlasmaShot.bbox = box2(-.1, -.1, .1, .1)
PlasmaShot.sprite = 'plasma-shot'
PlasmaShot.useGravity = false
PlasmaShot.damage = 3
PlasmaShot.rotCenter = {.5, .5}
PlasmaShot.drawCenter = {.5, .5}

function PlasmaShot:init(...)
	PlasmaShot.super.init(self, ...)
	
	self.shooter:hasKicked(self)
	self.angle = self.shooter.weapon.angle
	self.drawMirror = self.shooter.weapon.drawMirror
	--setTimeout(.2, function() self.remove = true end)
end

function PlasmaShot:update(dt, ...)
	if self.solidFlags ~= 0 then
		self.angle = game.time
	end
	PlasmaShot.super.update(self, dt, ...)
end

PlasmaShot.solidFlags = PlasmaShot.SOLID_SHOT
PlasmaShot.touchFlags = PlasmaShot.SOLID_WORLD + PlasmaShot.SOLID_YES + PlasmaShot.SOLID_NO
PlasmaShot.blockFlags = PlasmaShot.SOLID_WORLD + PlasmaShot.SOLID_YES

function PlasmaShot:touchTile(tileType, side, plane, x, y)
	if require 'zeta.script.tile.plasmabreak':isa(tileType) then
		game.level:clearTileAndBreak(x, y, self)
	end
	self:blast()
end

function PlasmaShot:touch(other, side)
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

	self.solidFlags = 0
	self.touchFlags = 0
	self.blockFlags = 0

	self.removeTime = game.time + 5/8
end

return PlasmaShot

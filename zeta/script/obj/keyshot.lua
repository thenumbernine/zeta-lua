--[[
This is a stupid idea for a puzzle version
(maybe I should put it in a sub-mod like "zeta-puzzle" that references back into zeta?)
it's a keycard for opening doors ...
... it goes away upon opening door (and perm-unlocks the door)
... and removes the item.
oh yeah and you also shoot it
Think of it like a sole missile from metroid.
But it can be multi-colored.
--]]
local class = require 'ext.class'
local Weapon = require 'zeta.script.obj.weapon'
local Object = require 'base.script.obj.object'
local KeyShot = class(Object)

KeyShot.bbox = box2(-.2, -.2, .2, .2)
KeyShot.sprite = 'blaster-shot'
KeyShot.useGravity = false
KeyShot.damage = 1
KeyShot.rotCenter = {.5, .5}
KeyShot.drawCenter = {.5, .5}

function KeyShot:init(...)
	KeyShot.super.init(self, ...)
	
	--self.angle = self.shooter.weapon.angle
	--self.drawMirror = self.shooter.weapon.drawMirror
	self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
	self.drawMirror = self.vel[1] < 0
	if self.drawMirror then self.angle = -self.angle end

--	self.removeTime = game.time + .2
end

KeyShot.solidFlags = KeyShot.SOLID_SHOT
KeyShot.touchFlags = bit.bor(KeyShot.SOLID_WORLD, KeyShot.SOLID_YES, KeyShot.SOLID_NO)
KeyShot.blockFlags = bit.bor(KeyShot.SOLID_WORLD, KeyShot.SOLID_YES)

function KeyShot:touchTile(tileType, side, plane, x, y)
	if require 'zeta.script.tile.blasterbreak':isa(tileType) then
		game.level:clearTileAndBreak(x,y, self)
	end
	self.remove = true
end

function KeyShot:touch(other, side)
	if self.remove then return true end
	if other == self.shooter then return true end	-- don't hit shooter
	if other.takeDamage then
		-- TODO in other:takeDamage
		-- only hurt if it isn't immune to this
		other:takeDamage(self.damage, self.shooter, self, side)
	end
	
	if self.color
	and require 'zeta.script.obj.door':isa(other)
	and vec4.__eq(self.color, other.color) 
	then
		other.spawnInfo.color = nil
		other.color = nil
		-- now find any door next to us (within 1 tile) 
		-- and (only if the color matches?)
		-- clear that as well?
		-- nah .... 
	end
	
	self.remove = true
end

return KeyShot

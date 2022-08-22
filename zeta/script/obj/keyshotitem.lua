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

-- 'Weapon' has hold and shoot stuff, but needs to be picked up
-- 'TouchItem' has touch-to-pickup
-- combine maybe?
-- 'AmmoItem' is TouchItem but modifies a max-ammo field instead of adds to inventory
local KeyShotItem = class(Weapon)

KeyShotItem.sprite = 'blaster-shot'

--[[ ok these are for player holding items...
KeyShotItem.playerHoldOffsetStanding = {.625, .5}
KeyShotItem.playerHoldOffsetDucking = {.625, .25}
--]]
-- [[ but these are for weapons ....
KeyShotItem.drawOffsetStanding = vec2(.5, 1.1)
KeyShotItem.drawOffsetDucking = vec2(.5, 0)
--]]

KeyShotItem.shotDelay = .1
KeyShotItem.shotSpeed = 35
KeyShotItem.shotClass = require 'zeta.script.obj.keyshot'
KeyShotItem.shotSound = 'shoot'
KeyShotItem.shotOffset = vec2(0, .45)

KeyShotItem.bbox = box2(-.2, -.2, .2, .2)
KeyShotItem.rotCenter = {.5, .5}
KeyShotItem.drawCenter = {.5, .5}

function KeyShotItem:init(args)
	KeyShotItem.super.init(self, args)
	-- make name unique by color
	-- that way player inventory will group by color (since it groups by class & name)
	self.name = 'key '..tostring(vec3(table.unpack(self.color)))
end

function KeyShotItem:doShoot(player, pos, vel)
	local player = self.heldby
	if player then
		-- TODO if we remove our held item / weapon then we should pick the next weapon in that .items[] bin
		-- and TODO if we run out of that bin but we have more items we should go to the next bin
		player:removeItem(self)
		self.remove = true
	end
	local shot = KeyShotItem.super.doShoot(self, player, pos, vel)
	shot.color = vec4(table.unpack(self.color))
	return shot
end

-- ok Weapon is an Item
-- but this is a TouchItem property
-- so maybe make it into TouchItem behavior?

-- this isn't the same as TouchItem tho, more like Item
function KeyShotItem:touch(other, side)
	if other == self.heldby then return true end	-- already holding

	if not require 'zeta.script.obj.hero':isa(other) then return true end
	self:playSound('powerup')

	self:playerGrab(other, side)
end


return KeyShotItem

local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local Hero = require 'zeta.script.obj.hero'

local Item = class(Object)
Item.canCarry = true
Item.canStoreInv = true
Item.playerHoldOffsetStanding = {.625, .125}
Item.playerHoldOffsetDucking = {.625, -.25}

-- I want breakblocks to block items
-- but I don't want items to block shots ...
--Item.solid = false
local BreakBlock = require 'zeta.script.obj.breakblock'
function Item:pretouch(other, side)
	if other:isa(BreakBlock) then return end
	return true	-- don't touch anything else
end

function Item:playerGrab(player, side)
	-- add item to player
	do
		local found = false
		for _,items in ipairs(player.items) do
			if self.class ~= require 'zeta.script.obj.keycard'	-- they have to be held uniquely
			and items[1].class == self.class
			then
				items:insert(self)
				found = true
				break
			end
		end
		if not found then
			player.items:insert(table{self})
		end
	end
	
	if self.isWeapon then
		player.weapon = self
	end
end

return Item

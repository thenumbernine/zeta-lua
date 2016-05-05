local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local Hero = require 'zeta.script.obj.hero'

local Item = class(Object)
Item.canCarry = true
Item.solid = false
Item.canStoreInv = true

function Item:playerGrab(player, side)
	-- add item to player
	do
		local found = false
		for _,items in ipairs(player.items) do
			if items[1].class == self.class then
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

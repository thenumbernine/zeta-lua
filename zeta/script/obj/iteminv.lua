-- subclass of Item that gives an object to the player inventory
-- that object is determined by invClass
local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'

local ItemInv = class(Item)

ItemInv.invClass = nil
function ItemInv:give(player, side)
	local invObj = self.invClass()
	player.items:insert(invObj)
	if invObj.weapon then
		player.weapon = invObj
	end
end

return ItemInv

local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local Hero = require 'zeta.script.obj.hero'

local Item = class(Object)
Item.canCarry = true
Item.solid = false
Item.canStoreInv = true

function Item:playerGrab(player, side)
	player.items:insert(self)
	if self.isWeapon then
		player.weapon = self
	end
end

return Item

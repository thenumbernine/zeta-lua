local class = require 'ext.class'
local TouchItem = require 'zeta.script.obj.touchitem'
local AmmoItem = class(TouchItem)
AmmoItem.amount = 1
--Ammoitem.ammo = 'Cells', 'Grenades', 'Missiles', etc ...
function AmmoItem:onGiveBonus(player)
	local field = 'ammo' ..self.ammo
	local max = 'maxAmmo' .. self.ammo
	player[field] = math.min(player[field] + self.amount, player[max])
end
return AmmoItem

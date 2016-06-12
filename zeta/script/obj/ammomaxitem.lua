local PowerupItem = require 'zeta.script.obj.powerupitem'
local AmmoMaxItem = class(PowerupItem)
AmmoMaxItem.amount = 1	-- how much
-- AmmoMaxItem.ammo = 'Cells' -- 'Grenades' -- etc ...

function AmmoMaxItem:onGiveBonus(player)
	local field = 'ammo' .. self.ammo
	player[field] = player[field] + self.amount
	local max = 'maxAmmo' .. self.ammo
	player[max] = player[max] + self.amount
end

return AmmoMaxItem

local AmmoMaxItem = behaviors(require 'zeta.script.obj.powerupitem',
	require 'zeta.script.behavior.crystalitem')
AmmoMaxItem.amount = 1	-- how much
-- AmmoMaxItem.ammo = 'Cells' -- 'Grenades' -- etc ...
function AmmoMaxItem:onGiveBonus(player)
	local field = 'ammo' .. self.ammo
	local max = 'maxAmmo' .. self.ammo
	player[field] = player[field] + self.amount
	player[max] = player[max] + self.amount
end
return AmmoMaxItem

local ItemBonus = require 'zeta.script.obj.itembonus'
local AmmoTank = class(ItemBonus)
AmmoTank.amount = 1	-- how much
-- AmmoTank.ammo = 'Cells' -- 'Grenades' -- etc ...

function AmmoTank:onGiveBonus(player)
	local field = 'ammo' .. self.ammo
	player[field] = player[field] + self.amount
	local max = 'maxAmmo' .. self.ammo
	player[max] = player[max] + self.amount
end

return AmmoTank

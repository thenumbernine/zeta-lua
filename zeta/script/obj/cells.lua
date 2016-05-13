local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local Cells = class(ItemBonus)
Cells.sprite = 'cells'
Cells.invSeq = 'stand5'
Cells.ammoCells = 1

function Cells:onGiveBonus(player)
	player.maxAmmoCells = player.maxAmmoCells + self.ammoCells
end

return Cells

local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local DefenseBonus = class(ItemBonus)
DefenseBonus.sprite = 'defense-bonus'
DefenseBonus.invSeq = 'stand2'	-- stop flashing!
DefenseBonus.defenseBonus = 1

function DefenseBonus:onGiveBonus(player)
	player.defenseStat = player.defenseStat + self.defenseBonus
end

return DefenseBonus

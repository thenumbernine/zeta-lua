local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local AttackBonus = class(ItemBonus)
AttackBonus.sprite = 'attack-bonus'
AttackBonus.invSeq = 'stand2'

function AttackBonus:onGiveBonus(player)
	player.attackStat = player.attackStat + 1
end

return AttackBonus

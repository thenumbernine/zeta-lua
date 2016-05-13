local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local AttackBonus = class(ItemBonus)
AttackBonus.sprite = 'attack-bonus'
AttackBonus.invSeq = 'stand2'
AttackBonus.attackBonus = 1

function AttackBonus:onGiveBonus(player)
	player.attackStat = player.attackStat + self.attackBonus
end

return AttackBonus

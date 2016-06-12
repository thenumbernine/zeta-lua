local PowerupItem = require 'zeta.script.obj.powerupitem'
local AttackBonus = class(PowerupItem)
AttackBonus.sprite = 'attack-bonus'
AttackBonus.invSeq = 'stand2'
AttackBonus.attackBonus = 1

function AttackBonus:onGiveBonus(player)
	player.attackStat = player.attackStat + self.attackBonus
end

return AttackBonus

local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local AttackBonus = class(ItemBonus)
AttackBonus.sprite = 'attack-bonus'
AttackBonus.invSeq = 'stand2'	-- stop flashing!

function AttackBonus:onGiveBonus(player)
	player.attackBonus = (player.attackBonus or 0) + 1
end
function AttackBonus:onLoseBonus(player)
	player.attackBonus = player.attackBonus - 1
end

return AttackBonus

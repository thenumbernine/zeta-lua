local class = require 'ext.class'
local ItemBonus = require 'zeta.script.obj.itembonus'

local DefenseBonus = class(ItemBonus)
DefenseBonus.sprite = 'defense-bonus'
DefenseBonus.invSeq = 'stand2'	-- stop flashing!

function DefenseBonus:onGiveBonus(player)
	player.defenseBonus = (player.defenseBonus or 0) + 1
end
function DefenseBonus:onLoseBonus(player)
	player.defenseBonus = player.defenseBonus - 1
end

return DefenseBonus

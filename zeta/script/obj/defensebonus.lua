local PowerupItem = require 'zeta.script.obj.powerupitem'
local DefenseBonus = class(PowerupItem)
DefenseBonus.sprite = 'defense-bonus'
DefenseBonus.invSeq = 'stand2'	-- stop flashing!
DefenseBonus.defenseBonus = 1

function DefenseBonus:onGiveBonus(player)
	player.defenseStat = player.defenseStat + self.defenseBonus
end

return DefenseBonus

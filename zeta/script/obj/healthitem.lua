local TouchItem = require 'zeta.script.obj.touchitem'
local HealthItem = class(TouchItem)
HealthItem.sprite = 'heart'

function HealthItem:onGiveBonus(player)
	player.health = math.min(player.health + 1, player.maxHealth)
end

return HealthItem

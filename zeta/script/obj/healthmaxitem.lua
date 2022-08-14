local behaviors = require 'base.script.behaviors'
local HealthMaxItem = behaviors(require 'zeta.script.obj.powerupitem',
	require 'zeta.script.behavior.crystalitem')
HealthMaxItem.sprite = 'heart'
HealthMaxItem.healthBonus = 1

function HealthMaxItem:onGiveBonus(player)
	player.maxHealth = player.maxHealth + self.healthBonus
	player.health = player.health + self.healthBonus
end

return HealthMaxItem

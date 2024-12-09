local Mushroom = require 'base.script.behaviors'(
	require 'base.script.obj.object',
	require 'neko.script.behavior.walkenemy'
)
Mushroom.sprite = 'mushroom'
Mushroom.touchDamage = 1
Mushroom.maxHealth = 2
Mushroom.turnsAtLedge = true
return Mushroom

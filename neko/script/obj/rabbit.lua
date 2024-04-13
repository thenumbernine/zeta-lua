local behaviors = require 'base.script.behaviors'
local Rabbit = behaviors(
	require 'base.script.obj.object'
	--,require 'neko.script.behavior.walkenemy'
)
Rabbit.sprite = 'rabbit'
Rabbit.touchDamage = 1
Rabbit.maxHealth = 2
Rabbit.turnsAtLedge = true
return Rabbit

local behaviors = require 'base.script.behaviors'
local SpeedBooster = behaviors(require 'zeta.script.obj.item',
	require 'zeta.script.behavior.crystalitem')
SpeedBooster.name = 'speedbooster'
SpeedBooster.sprite = 'speed-booster'
return SpeedBooster

local Goomba = behaviors(
	require 'base.script.obj.object',
	require 'mario.script.behavior.walkenemy')

Goomba.sprite = 'goomba'
Goomba.seq = 'walk'
Goomba.touchDamage = 1
Goomba.health = 2
Goomba.turnsAtLedge = true	-- false, I know

return Goomba

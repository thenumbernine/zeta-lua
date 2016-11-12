local game = require 'base.script.singleton.game'

local Koopa = behaviors(
	require 'base.script.obj.object',
	require 'mario.script.behavior.walkenemy')

Koopa.sprite = 'koopa'
Koopa.seq = 'walk'
Koopa.maxHealth = 5
Koopa.touchDamage = 2
Koopa.turnsAtLedge = true

function Koopa:die()
	local Shell = require 'mario.script.obj.shell'		-- do so here so we don't get a require() loop
	setmetatable(self, Shell)
	self.seq = 'eyes'
	self.enterShellTime = game.time
	self.dir = 0
end

return Koopa

local class = require 'ext.class'
local WalkEnemy = require 'mario.script.obj.walkenemy'
local game = require 'base.script.singleton.game'

local Koopa = class(WalkEnemy)

Koopa.sprite = 'koopa'
Koopa.seq = 'walk'
Koopa.turnsAtLedge = true
Koopa.spinJumpDestroys = true

function Koopa:playerBounce(other)
	local Shell = require 'mario.script.obj.shell'		-- do so here so we don't get a require() loop
	setmetatable(self, Shell)
	self.seq = 'eyes'
	self.enterShellTime = game.time
	self.dir = 0
end

return Koopa

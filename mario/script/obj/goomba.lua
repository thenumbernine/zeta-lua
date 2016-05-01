local class = require 'ext.class'
local WalkEnemy = require 'mario.script.obj.walkenemy'
local game = require 'base.script.singleton.game'


local Goomba = class(WalkEnemy)

Goomba.sprite = 'goomba'
Goomba.seq = 'walk'
Goomba.spinJumpDestroys = true

function Goomba:die(other)
	self.seq = 'die'
	self.dead = true
	self.removeTime = game.time + 1
	self.collidesWithObjects = false
	self.vel[1] = 0
end

return Goomba
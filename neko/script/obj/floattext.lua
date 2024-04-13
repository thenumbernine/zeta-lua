-- in neko and zeta, maybe move ot base?

local gui = require 'base.script.singleton.gui'
local game = require 'base.script.singleton.game'

local Tick = require 'base.script.obj.object':subclass()

function Tick:init(args)
	Tick.super.init(self, args)

	self.solidFlags = 0
	self.touchFlags = 0
	self.blockFlags = 0
	self.removeTime = game.time + 1
	self.vel[2] = 1
	self.useGravity = false
end

function Tick:draw()
	gui.font:drawUnpacked(
		self.pos[1], self.pos[2]+2, 
		1, -1, 
		self.text)
end

return Tick

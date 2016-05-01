local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local addTakesDamage = require 'zeta.script.obj.takesdamage'
local game = require 'base.script.singleton.game'

local Geemer = class(Object)
addTakesDamage(Geemer)
Geemer.sprite = 'geemer'
Geemer.solid = true
Geemer.health = 1
Geemer.nextChangeDirTime = -1
Geemer.baseVelX = 0
Geemer.baseVelY = 0

function Geemer:update(...)
	Geemer.super.update(self, ...)

	self.vel[1] = self.baseVelX
	self.vel[2] = self.baseVelY
	if game.time > self.nextChangeDirTime then
		self.nextChangeDirTime = game.time + 1 + math.random()
		self.baseVelX = math.random(2) == 1 and -5 or 5
		self.baseVelY = math.random(2) == 1 and 3 or 0
	end
end

local Hero = require 'zeta.script.obj.hero'
function Geemer:touch(other, side)
	if other:isa(Hero) then
		other:takeDamage(1, self, self, side)
	end
end

return Geemer

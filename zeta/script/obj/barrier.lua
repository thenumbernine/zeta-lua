local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local box2 = require 'vec.box2'

local Barrier = class(Object)
Barrier.sprite = 'barrier'
Barrier.solid = false
Barrier.timeOn = 3
Barrier.timeOff = 1
Barrier.damage = 2
Barrier.bbox = box2(-.3, 0, .3, 3)

function Barrier:init(args)
	Barrier.super.init(self, args)
	
	if args.timeOn then self.timeOn = tonumber(args.timeOn) end
	if args.timeOff then self.timeOff = tonumber(args.timeOff) end
	if args.damage then self.damage = tonumber(args.damage) end
	
	self.timeOffset = math.random() * (self.timeOn + self.timeOff)
end

function Barrier:pretouch(other, side)
	if self.shockEndTime > game.time and other.takeDamage then
		other:takeDamage(self.damage, self, self, side)
	end
	return true
end

function Barrier:update(dt)
	if not game.session.defensesDeactivated then
		local t = (game.time + self.timeOffset) % (self.timeOn + self.timeOff)
		self.shockEndTime = t < self.timeOn and game.time + .5 + .5 * math.random() or 0
	end
	if self.shockEndTime > game.time then
		self.sprite = 'barrier' -- class default
	else
		self.sprite = false	-- tell Object:draw not to draw anything
	end
end

return Barrier

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
Barrier.shockEndTime = -1

function Barrier:init(args)
	Barrier.super.init(self, args)
	
	if args.timeOn then self.timeOn = tonumber(args.timeOn) end
	if args.timeOff then self.timeOff = tonumber(args.timeOff) end
	if args.damage then self.damage = tonumber(args.damage) end
	
	self.timeOffset = math.random() * (self.timeOn + self.timeOff)
	self.sprite = false
end

function Barrier:pretouch(other, side)
	if self.shockEndTime > game.time then
		if other.takeDamage then
			other:takeDamage(self.damage, self, self, side)
		end
		-- shots and grenades
		if other.blast then other:blast() end
	end
	return true
end

Barrier.solidFlags = 0
Barrier.touchFlags = Barrier.SOLID_YES + Barrier.SOLID_GRENADE
Barrier.blockFlags = 0 
-- i would like to have block grenade and then touch return true to optionally not block 
-- ... but it is always blocking.
-- that appears to be due to the grenade's touch running, then it bounces ... 
-- then it calls this touch and gets a 'dontblock' true
-- but by then the velocity is already bounced
-- TODO incorporate bouncing into the movement model?
--Barrier.blockFlags = Barrier.SOLID_GRENADE
Barrier.touch_v2 = Barrier.pretouch

function Barrier:update(dt)
	if not game.session.defensesDeactivated then
		local t = (game.time + self.timeOffset) % (self.timeOn + self.timeOff)
		if t < self.timeOn then
			self.shockEndTime = game.time + .5 + .5 * math.random()
		else
			self.shockEndTime = -1
		end
	end
	if self.shockEndTime > game.time then
		self.sprite = 'barrier' -- class default
	else
		self.sprite = false	-- tell Object:draw not to draw anything
	end
end

return Barrier

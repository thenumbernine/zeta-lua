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
Barrier.circuit = 'Main'

function Barrier:init(...)
	Barrier.super.init(self, ...)
	self.timeOffset = math.random() * (self.timeOn + self.timeOff)
	self.sprite = false
end

function Barrier:pretouch(other, side)
	if self.shockEndTime > game.time then
		if other.takeDamage then
			other:takeDamage(self.damage, self, self, side)
		end
		-- stop grenades immediately.  stops missiles as well.
		if other.blast then other:blast() end
	end
	return true
end

Barrier.solidFlags = 0
Barrier.touchFlags = Barrier.SOLID_YES -- for player
					+ Barrier.SOLID_NO -- for geemer
					+ Barrier.SOLID_GRENADE -- for grenades
Barrier.blockFlags = 0 
Barrier.touchPriority = 9	-- above shots, below hero
Barrier.touch_v2 = Barrier.pretouch

function Barrier:update(dt)
	if game.session['defensesActive_'..self.circuit] then
		local t = (game.time + self.timeOffset) % (self.timeOn + self.timeOff)
		if t < self.timeOn then
			self.shockEndTime = game.time + .5 + .5 * math.random()
		else
			self.shockEndTime = -1
		end
	end
	if self.shockEndTime > game.time then
		-- if we're turning on then play a electricity sound
		if self.sprite == false
		and math.random(5) == 1 
		then
			self:playSound'electricity'
		end
		
		self.sprite = 'barrier' -- class default
	else
		self.sprite = false	-- tell Object:draw not to draw anything
	end
end

return Barrier

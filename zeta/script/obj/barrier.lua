local box2 = require 'vec.box2'
local game = require 'base.script.singleton.game'
local behaviors = require 'base.script.behaviors'
local Barrier = behaviors(require 'base.script.obj.object'
	,require 'zeta.script.behavior.deathtopieces'
)
Barrier.sprite = 'barrier'
Barrier.timeOn = .3
Barrier.timeOff = 3
Barrier.damage = 2
Barrier.bbox = box2(-.3, 0, .3, 3)
Barrier.shockEndTime = -1
Barrier.circuit = 'Main'
Barrier.maxHealth = 10

function Barrier:init(...)
	Barrier.super.init(self, ...)
	self.timeOffset = math.random() * (self.timeOn + self.timeOff)
	self.sprite = false
end

Barrier.solidFlags = 0
Barrier.touchFlags = Barrier.SOLID_YES -- for player
					+ Barrier.SOLID_NO -- for geemer
					+ Barrier.SOLID_GRENADE -- for grenades
					+ Barrier.SOLID_SHOT
Barrier.blockFlags = 0 
Barrier.touchPriority = 9	-- above shots, below hero
function Barrier:touch(other, side)
	if self.shockEndTime > game.time then
		if other.takeDamage then
			other:takeDamage(self.damage, self, self, side)
		end
		-- stop grenades immediately.  stops missiles as well.
		if other.blast then other:blast() end
	end
	
	return true
end


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
		self.touchFlags = self.SOLID_YES + self.SOLID_NO + self.SOLID_GRENADE + self.SOLID_SHOT 
	else
		self.sprite = false	-- tell Object:draw not to draw anything
		self.touchFlags = self.SOLID_YES + self.SOLID_NO
	end
end

return Barrier

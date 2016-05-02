local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local addTakesDamage = require 'zeta.script.obj.takesdamage'
local game = require 'base.script.singleton.game'

local Geemer = class(Object)
addTakesDamage(Geemer)
Geemer.sprite = 'geemer'
Geemer.solid = true
Geemer.health = 1

Geemer.attackDist = 3
Geemer.jumpVel = 10
Geemer.runVel = 5

Geemer.alertDist = 5
Geemer.nextShakeTime = -1
Geemer.shakeEndTime = -1

function Geemer:update(dt)
	Geemer.super.update(self, dt)

	if self.onground then 
		for _,player in ipairs(game.players) do
			local delta = player.pos - self.pos
			local len = delta:length()
			if len < self.attackDist then
				self.vel[2] = self.jumpVel
				self.vel[1] = delta[1] > 0 and self.runVel or -self.runVel
			elseif len < self.alertDist then
				if game.time > self.nextShakeTime then
					self.shakeEndTime = game.time + 1
					self.nextShakeTime = game.time + 3
				end
			end
		end
	end
end

local Hero = require 'zeta.script.obj.hero'
function Geemer:touch(other, side)
	if other:isa(Hero) then
		other:takeDamage(1, self, self, side)
	end
end

function Geemer:draw(...)
	local ofs = 0
	if game.time < self.shakeEndTime then
		ofs = 1/16 * math.sin(game.time * 100)
		self.pos[1] = self.pos[1] + ofs
	end
	Geemer.super.draw(self, ...)
	if game.time < self.shakeEndTime then
		self.pos[1] = self.pos[1] - ofs
	end
end

return Geemer

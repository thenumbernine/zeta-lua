local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local Enemy = require 'zeta.script.obj.enemy'
local stateMachineBehavior = require 'zeta.script.obj.statemachine'
local hurtsToTouchBehavior = require 'zeta.script.obj.hurtstotouch'
local game = require 'base.script.singleton.game'

local Bat = class(hurtsToTouchBehavior(stateMachineBehavior(Enemy)))
Bat.sprite = 'bat'
Bat.useGravity = false
Bat.solidFlags = Bat.SOLID_NO
--Bat.blockFlags = Bat.SOLID_SHOT	-- not even the world?
Bat.maxHealth = 5
Bat.touchDamage = 3
Bat.itemDrops = {
	['zeta.script.obj.heart'] = .1,
}

function Bat:init(...)
	Bat.super.init(self, ...)
	self.time = math.random() * 3
end

Bat.speed = 5
Bat.initialState = 'searching'
Bat.searchDist = 5
Bat.states = {
	searching = {
		update = function(self, dt)
			self.time = self.time + dt
			self.vel[1] = -3 * math.sin(self.time * 3)
			self.vel[2] = 3 * math.cos(self.time * 3)
			for _,player in ipairs(game.players) do
				local delta = player.pos - self.pos
				if delta:lenSq() < self.searchDist * self.searchDist then
					self.madAt = player
					self:setState'angry'
				end
			end
		end,
	},
	angry = {
		update = function(self, dt)
			local delta = (self.madAt.pos - self.pos):normalize()
			self.vel[1] = delta[1] * self.speed
			self.vel[2] = delta[2] * self.speed
			if game.time > self.stateStartTime + 2 then
				self:setState'searching'
			end
		end,
	},
}

function Bat:hit(damage, attacker, inflicter, side)
	Bat.super.hit(self, damage, attacker, inflicter, side)
	self.madAt = attacker
	if self.state ~= 'angry' then self:setState'angry' end
end

return Bat

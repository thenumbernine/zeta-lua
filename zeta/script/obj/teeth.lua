local Enemy = require 'zeta.script.obj.enemy'
local stateMachineBehavior = require 'zeta.script.obj.statemachine'
local hurtsToTouchBehavior = require 'zeta.script.obj.hurtstotouch'
local game = require 'base.script.singleton.game'
local Teeth = class(hurtsToTouchBehavior(stateMachineBehavior(Enemy)))
Teeth.sprite = 'teeth'
Teeth.maxHealth = 5
Teeth.bbox = box2(-.5, -.5, .5, .5)
Teeth.rotCenter = {.5,.5}
Teeth.drawCenter = {.5,.5}
Teeth.initialState = 'searching'
Teeth.drawScale = {4,4}
Teeth.touchDamage = 1

Teeth.itemDrops = {
	['zeta.script.obj.heart'] = .1,
}

Teeth.searchDist = 5
Teeth.states.searching = {
	update = function(self)
		for _,player in ipairs(game.players) do
			local delta = player.pos - self.pos
			if delta:lenSq() < self.searchDist * self.searchDist then
				self.madAt = player
				self:setState'mad'
			end
		end
	end,
}

Teeth.solidFlags = Teeth.SOLID_NO
Teeth.blockFlags = Teeth.SOLID_WORLD

Teeth.speed = 7
Teeth.jumpVel = 15
Teeth.jawFreq = 10
Teeth.angle = 90
Teeth.jawAngle = 0
Teeth.states.mad = {
	enter = function(self)
		self.seq = 'chomp'
	end,
	update = function(self)
		local delta = (self.madAt.pos - self.pos):normalize()
		self.vel[1] = delta[1] * self.speed
		if self.onground then
			--self.vel[2] = delta[2] * self.speed
			self.vel[2] = self.jumpVel
		end
		self.angle = math.deg(math.atan2(delta[2], delta[1]))
	end,
}

return Teeth

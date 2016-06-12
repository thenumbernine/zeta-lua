local game = require 'base.script.singleton.game'
local Teeth = behaviors(require 'zeta.script.obj.enemy',
	require 'zeta.script.behavior.statemachine',
	require 'zeta.script.behavior.hurtstotouch')

Teeth.sprite = 'teeth'
Teeth.maxHealth = 5
Teeth.bbox = box2(-.5, -.5, .5, .5)
Teeth.rotCenter = {.5,.5}
Teeth.drawCenter = {.5,.5}
Teeth.initialState = 'searching'
Teeth.drawScale = {4,4}
Teeth.solidFlags = Teeth.SOLID_NO
Teeth.blockFlags = Teeth.SOLID_WORLD

-- hurtsToTouchBehavior
Teeth.touchDamage = 1

-- itemDropBehavior
Teeth.itemDrops = {
	['zeta.script.obj.healthitem'] = .1,
	['zeta.script.obj.cellitem'] = .1,
	['zeta.script.obj.grenadeitem'] = .1,
	['zeta.script.obj.missileitem'] = .1,
}

-- stateMachineBehavior

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

Teeth.speed = 7
Teeth.jumpVel = 10
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

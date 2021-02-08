local Zoomer = behaviors(require 'zeta.script.obj.enemy',
	require 'zeta.script.behavior.hurtstotouch')
Zoomer.sprite = 'zoomer'
Zoomer.useGravity = false
Zoomer.speed = 3
Zoomer.maxHealth = 10
Zoomer.touchDamage = 2

Zoomer.solidFlags = Zoomer.SOLID_NO
Zoomer.touchFlags = Zoomer.SOLID_YES
Zoomer.blockFlags = Zoomer.SOLID_WORLD

function Zoomer:init(...)
	Zoomer.super.init(self, ...)
	self.vel[1] = self.speed
end

function Zoomer:touchTile(tile, side, normal)
	if normal[1] > 0 then
		self.vel[1] = self.speed
	elseif normal[1] < 0 then
		self.vel[1] = -self.speed
	end
	self.pos[1] = self.lastpos[1] + self.vel[1] * .1
	self.pos[2] = self.lastpos[2]
	self.vel[2] = 0
	self.drawMirror = self.vel[1] < 0
	return true
end

function Zoomer:modifyDamageTaken(damage, attacker, inflicter, side)
	-- TODO damage type
	local Missile = require 'zeta.script.obj.missile'
	local Grenade = require 'zeta.script.obj.grenade'
	local Hero = require 'zeta.script.obj.hero'
	if not (Missile:isa(inflicter)
		or Grenade:isa(inflicter)
		or Hero:isa(inflicter))
	then
		return 0
	end
end

Zoomer.itemDrops = {
	['zeta.script.obj.healthitem'] = .1,
	['zeta.script.obj.cellitem'] = .1,
	['zeta.script.obj.grenadeitem'] = .1,
	['zeta.script.obj.missileitem'] = .1,
}

return Zoomer

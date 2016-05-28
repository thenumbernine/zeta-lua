local class = require 'ext.class'
local Enemy = require 'zeta.script.obj.enemy'
local hurtsToTouchBehavior = require 'zeta.script.obj.hurtstotouch'

local Zoomer = class(hurtsToTouchBehavior(Enemy))
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

function Zoomer:touchTile()
	self.vel[1] = -self.vel[1]
	self.drawMirror = self.vel[1] < 0
end

local Missile = require 'zeta.script.obj.missilelauncher'.shotClass
local Grenade = require 'zeta.script.obj.grenadelauncher'.shotClass
function Zoomer:modifyDamageTaken(damage, attacker, inflicter, side)
	-- TODO damage type
	if not (inflicter:isa(Missile)
		or inflicter:isa(Grenade))
	then
		return 0
	end
end

return Zoomer

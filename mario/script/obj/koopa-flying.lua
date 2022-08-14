local behaviors = require 'base.script.behaviors'
local FlyKoopa = behaviors(
	require 'base.script.obj.object',
	require 'mario.script.behavior.flyenemy')
FlyKoopa.sprite = 'koopa'
FlyKoopa.seq = 'walk'
FlyKoopa.maxHealth = 10
FlyKoopa.touchDamage = 2
FlyKoopa.useGravity = false
--[[ TODO fly back and forth
function FlyKoopa:update(...)
end
--]]
function FlyKoopa:takeDamage(...)
	setmetatable(self, require 'mario.script.obj.koopa')
	FlyKoopa.super.takeDamage(self, ...)
end
return FlyKoopa

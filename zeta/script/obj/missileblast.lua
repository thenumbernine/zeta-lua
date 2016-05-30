local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local MissileBlast = class(Object)
MissileBlast.solid = false
MissileBlast.collidesWithObjects = false
MissileBlast.collidesWithWorld = false
MissileBlast.useGravity = false
MissileBlast.sprite = 'missileblast'
MissileBlast.solidFlags = 0
MissileBlast.touchFlags = 0
MissileBlast.blockFlags = 0
function MissileBlast:init(...)
	MissileBlast.super.init(self, ...)
	self.removeTime = game.time + .75
	self.seqStartTime = game.time
end
return MissileBlast

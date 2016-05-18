local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local MissileBlast = class(Object)
local game = require 'base.script.singleton.game'

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

local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local MissileBlast = class(Object)
local game = require 'base.script.singleton.game'

MissileBlast.solid = false
MissileBlast.collidesWithObjects = false
MissileBlast.collidesWithWorld = false
MissileBlast.useGravity = false
MissileBlast.sprite = 'missileblast'

function MissileBlast:init(args)
	MissileBlast.super.init(self, args)
	self.removeTime = game.time + .75
	self.seqStartTime = game.time
end

return MissileBlast

local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local BeamShot = class(GameObject)

BeamShot.sprite = 'shot'
BeamShot.useGravity = false
BeamShot.solid = false

function BeamShot:update(...)
	BeamShot.super.update(self, ...)
end

function BeamShot:touchTile(tile, side)
	-- generalize this for all projectiles
	if tile.onShoot then
		tile:onShoot(self, side)
	end
	
	self.vel[1] = 0
	self.vel[2] = 0
	self.collidesWithWorld = false
	self.collidesWithObjects = false
	self.removeTime = game.time + 1
end

return BeamShot
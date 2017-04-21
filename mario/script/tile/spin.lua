local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local game = require 'base.script.singleton.game'

local SpinTile = class(Tile)
SpinTile.name = 'spinblock'
SpinTile.sprite = 'spinblock'
SpinTile.seq = 'stand'
SpinTile.solid = true

function SpinTile:onHit(other)
	-- hit everything above this tile	
	game:hitAllOnTile(self.pos[1], self.pos[2]+1, other)
	
	local SpinBlock = require 'mario.script.obj.spinblock'
	SpinBlock{
		pos = self.pos + game.level.pos + vec2(.5, 0),
		tilePos = self.pos,
	}
	self:makeEmpty()
end

function SpinTile:onSpinJump(other)
	local SpinParticle = require 'mario.script.obj.spinparticle'
	SpinParticle.breakAt(self.pos[1] + .5, self.pos[2] + .5)
	self:makeEmpty()
end

return SpinTile

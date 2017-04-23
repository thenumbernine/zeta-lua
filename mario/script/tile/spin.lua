local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local game = require 'base.script.singleton.game'

local SpinTile = class(Tile)
SpinTile.name = 'spinblock'
SpinTile.sprite = 'spinblock'
SpinTile.seq = 'stand'
SpinTile.solid = true

function SpinTile:onHit(other, x, y)
	-- hit everything above this tile	
	game:hitAllOnTile(x, y+1, other)

	local SpinBlock = require 'mario.script.obj.spinblock'
	SpinBlock{
		pos = vec2(x+.5, y),
		tilePos = vec2(x,y),
	}
	game.level:makeEmpty(x,y)
end

function SpinTile:onSpinJump(other, x,y)
	local SpinParticle = require 'mario.script.obj.spinparticle'
	SpinParticle.breakAt(x + .5, y + .5)
	game.level:makeEmpty(x,y)
end

return SpinTile

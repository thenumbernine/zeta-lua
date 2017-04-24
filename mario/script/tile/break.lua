local Tile = require 'base.script.tile.tile'
local Mario = require 'mario.script.obj.mario'
local game = require 'base.script.singleton.game'

local BreakTile = class(Tile)
BreakTile.solid = true
BreakTile.sprite = 'breakblock'
BreakTile.name = 'breakblock'
BreakTile.seq = 'stand'

function BreakTile:onHit(other, x, y)
	-- hit everything above this tile	
	game:hitAllOnTile(x, y+1, other)

	-- TODO hit things within the tile

	--if Mario.is(other) and other.big then 
	local SpinParticle = require 'mario.script.obj.spinparticle'
	SpinParticle.breakAt(x + .5, y)
	game.level:makeEmpty(x,y)
	--end
end

return BreakTile

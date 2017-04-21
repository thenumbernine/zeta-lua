local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local game = require 'base.script.singleton.game'
local vec2 = require 'vec.vec2'

local BreakTile = class(Tile)
BreakTile.solid = true
BreakTile.sprite = 'breakblock'
BreakTile.seq = 'stand'

function BreakTile:onHit(other)
	-- hit everything above this tile	
	game:hitAllOnTile(self.pos[1], self.pos[2]+1, other)

	local Mario = require 'mario.script.obj.mario'
	if other:isa(Mario) and not other.big then return end
	
	local SpinParticle = require 'mario.script.obj.spinparticle'
	SpinParticle.breakAt(self.pos[1] + .5, self.pos[2] + .5)

	self:makeEmpty()
end

return BreakTile

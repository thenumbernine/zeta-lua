local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local SpikeTile = class(Tile)
SpikeTile.usesTemplate = true
SpikeTile.name = 'spike'
SpikeTile.template = 'spike'
SpikeTile.solid = true

function SpikeTile:touch(other)
	local Mario = require 'mario.script.obj.mario'
	if not other:isa(Mario) then return end
	
	other:hit()	-- hit by spike?
end

return SpikeTile

local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local Tile = require 'base.script.tile.tile'
local PickUpBlock = require 'mario.script.obj.pickupblock'
local game = require 'base.script.singleton.game'

local PickUpTile = class(Tile)
PickUpTile.solid = true
PickUpTile.name = 'pickupblock'
PickUpTile.sprite = 'pickupblock'
PickUpTile.seq = 'stand'

function PickUpTile:onCarry(player,x,y)
	local block = PickUpBlock{pos=vec2(x+.5,y)}
	player:setHeld(block)
	game.level:makeEmpty(x,y)
end

return PickUpTile

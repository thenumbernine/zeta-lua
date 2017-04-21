local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local PickUpBlock = require 'mario.script.obj.pickupblock'
local game = require 'base.script.singleton.game'

local PickUpTile = class(Tile)
PickUpTile.solid = true
PickUpTile.sprite = 'pickupblock'
PickUpTile.seq = 'stand'

function PickUpTile:onCarry(player)
	local block = PickUpBlock{pos=self.pos + game.level.pos + vec2(.5,0)}
	player:setHeld(block)
	self:makeEmpty()
end

return PickUpTile

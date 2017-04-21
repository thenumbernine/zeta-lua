local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local VineTile = class(Tile)
VineTile.sprite = 'vine'
VineTile.seq = 'stand'
VineTile.canClimb = true

return VineTile

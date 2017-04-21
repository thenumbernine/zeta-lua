local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local VineTile = class(Tile)
VineTile.name = 'vine'
VineTile.sprite = 'vine'
VineTile.seq = 'stand'
VineTile.canClimb = true

return VineTile

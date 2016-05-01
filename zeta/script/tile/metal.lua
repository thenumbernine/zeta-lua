local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local MetalTile = class(Tile)
MetalTile.solid = true
MetalTile.sprite = 'tile-metal'
MetalTile.seq = 'stand'

return MetalTile

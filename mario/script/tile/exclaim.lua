local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local ExclaimTile = class(Tile)
ExclaimTile.name = 'exclaimblock'
ExclaimTile.sprite = 'exclaimblock'
ExclaimTile.seq = 'stand'
ExclaimTile.solid = true

return ExclaimTile

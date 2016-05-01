local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local SolidTile = class(Tile)
SolidTile.solid = true
SolidTile.usesTemplate = true

return SolidTile

local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local NotSolidTile = class(Tile)
NotSolidTile.usesTemplate = true

return NotSolidTile

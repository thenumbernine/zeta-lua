local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local FenceTile = class(Tile)
FenceTile.usesTemplate = true
FenceTile.name = 'fence'
FenceTile.template = 'fence'
FenceTile.seam2 = 'fence'
FenceTile.canClimb = true

return FenceTile

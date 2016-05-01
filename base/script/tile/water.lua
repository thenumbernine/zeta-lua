local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local WaterParticle = require 'base.script.fluid.water'

local WaterTile = class(Tile)
WaterTile.fluidClass = WaterParticle

return WaterTile

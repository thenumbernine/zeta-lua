local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local Water = class(Tile)
Water.name = 'water'
Water.canSwim = true
return Water

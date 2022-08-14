local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local Solid = class(Tile)
Solid.name = 'solid'
Solid.solid = true
return Solid

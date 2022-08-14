local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local Ladder = class(Tile)
Ladder.name = 'ladder'
Ladder.canClimb = true
return Ladder

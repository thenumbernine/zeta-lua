local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local Ladder = class(Tile)
Ladder.sprite = 'tile-ladder'
Ladder.seq = 'stand'
Ladder.canClimb = true

return Ladder

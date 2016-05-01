local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local Vine = class(Tile)
Vine.sprite = 'vine'
Vine.seq = 'stand'
Vine.canClimb = true

return Vine

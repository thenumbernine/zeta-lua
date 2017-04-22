local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local StoneTile = class(Tile)
StoneTile.solid = true
StoneTile.name = 'stone'
StoneTile.sprite = 'stoneblock'
StoneTile.seq = 'stand'

return StoneTile

local Tile = require 'base.script.tile.tile'
local class = require 'ext.class'

local GrassTile = class(Tile)
GrassTile.sprite = 'grasstile'
GrassTile.seq = 'stand'

return GrassTile
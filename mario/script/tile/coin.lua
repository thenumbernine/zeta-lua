local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local CoinTile = class(Tile)
CoinTile.sprite = 'coin'
CoinTile.seq = 'stand'

return CoinTile

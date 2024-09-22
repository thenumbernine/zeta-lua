local Tile = require 'base.script.tile.tile'
local CoinTile = Tile:subclass()
CoinTile.name = 'coin'
CoinTile.sprite = 'coin'
CoinTile.seq = 'stand'
return CoinTile

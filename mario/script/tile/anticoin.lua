local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local AntiCoinTile = class(Tile)
AntiCoinTile.name = 'anticoin'
AntiCoinTile.sprite = 'anticoin'
AntiCoinTile.seq = 'stand'
AntiCoinTile.solid = true

return AntiCoinTile

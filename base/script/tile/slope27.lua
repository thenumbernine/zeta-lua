local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local Slope27Tile = class(Tile)
Slope27Tile.solid = true
Slope27Tile.usesTemplate = true
Slope27Tile.diag = 2	-- 27'

return Slope27Tile

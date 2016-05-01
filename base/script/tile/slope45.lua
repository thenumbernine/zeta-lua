local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local Slope45Tile = class(Tile)
Slope45Tile.solid = true
Slope45Tile.usesTemplate = true
Slope45Tile.diag = 1	-- 45'

return Slope45Tile

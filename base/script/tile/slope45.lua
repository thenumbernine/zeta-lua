local Tile = require 'base.script.tile.tile'
local Slope45 = class(Tile)
Slope45.solid = true
Slope45.diag = 1
return Slope45

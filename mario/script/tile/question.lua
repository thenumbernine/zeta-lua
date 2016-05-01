local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'

local QuestionTile = class(Tile)
QuestionTile.solid = true
QuestionTile.sprite = 'questionblock'
QuestionTile.seq = 'stand'

return QuestionTile

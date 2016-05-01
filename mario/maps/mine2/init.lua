-- [=[
local game = require 'base.script.singleton.game'
local tilekeys = require 'base.script.tiles'

local tileclasses = {}
for _,key in ipairs(tilekeys) do
	if key.tile and not key.tile.diag and not key.tile.usesTemplate then
		table.insert(tileclasses, key.tile)
	end
end

-- now hack up the whole level from top to bottom
-- do it by clumps of tiles ... or something
local level = game.level
for x=1,level.size[1] do
	local tilecol = level.tile[x]
	for y=1,level.size[2] do
		local tile = tilecol[y]
		
		if tile.solid and math.random() < .3 then
		
			-- now change the tile.
			setmetatable(tile, tileclasses[math.random(#tileclasses)])
		end
	end
end
level:alignTileTemplates(1,1,level.size[1], level.size[2])
--]=]

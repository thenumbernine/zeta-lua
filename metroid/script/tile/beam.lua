local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local game = require 'base.script.singleton.game'

local BeamTile = class(Tile)

BeamTile.respawnTime = 5
BeamTile.usesTemplate = true
BeamTile.solid = true

-- maybe onShoot or something?
function BeamTile:onShoot(other, side)
	if other:isa(require 'metroid.script.obj.beamshot') then
		self:respawn()
	end
end

function BeamTile:respawn()
	local respawnTime = self.respawnTime
	local x,y = unpack(self.pos)
	
	-- TODO do this for any block that 
	self:makeEmpty()
	self.solid = false	-- 'false' to override default 'true'
	game.level:alignTileTemplates(x,y,x,y)
	setTimeout(respawnTime, function()
		setmetatable(self, BeamTile)			-- hmm, not refreshing the tile's image, though it is getting those around the tile
		self.solid = nil	-- clear to get the default 'true'
		game.level:alignTileTemplates(x,y,x,y)
	end)
end

return BeamTile